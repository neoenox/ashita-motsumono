import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_settings.dart';
import 'purchase_entitlement_repository.dart';
import 'purchase_state.dart';
import 'purchase_verification_service.dart';
import 'verified_entitlement_cache.dart';

abstract class PurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseGateway implements PurchaseGateway {
  InAppPurchaseGateway([InAppPurchase? purchase])
    : _purchase = purchase ?? InAppPurchase.instance;

  final InAppPurchase _purchase;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchase.purchaseStream;

  @override
  Future<bool> isAvailable() => _purchase.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _purchase.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _purchase.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _purchase.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _purchase.completePurchase(purchase);
}

abstract class PurchaseProvider extends ChangeNotifier {
  bool get adRemoved;
  bool get aiAccess;
  bool get busy;
  bool get restoring => false;
  bool get entitlementResolved => true;
  PurchaseState? get state => null;
  String get priceLabel;
  String get aiPriceLabel;
  bool get canPurchase;
  bool get canPurchaseAi;
  String? get statusMessage;
  Future<void> get ready;

  static const productId = String.fromEnvironment(
    'IAP_REMOVE_ADS_PRODUCT_ID',
    defaultValue: 'remove_ads',
  );
  static const aiProductId = String.fromEnvironment(
    'IAP_AI_ACCESS_PRODUCT_ID',
    defaultValue: 'ai_analysis',
  );

  Future<void> purchase();
  Future<void> purchaseAi();
  Future<void> restore();

  Future<String?> getAiAccessToken() async => null;
}

class AppPurchaseProvider extends PurchaseProvider {
  AppPurchaseProvider(
    AppSettings settings, {
    PurchaseGateway? gateway,
    PurchaseVerifier? verifier,
  }) : _purchase = gateway ?? InAppPurchaseGateway(),
       _verifier = verifier ?? PurchaseVerificationService(),
       _ownsVerifier = verifier == null,
       _entitlements = PurchaseEntitlementRepository(settings),
       _state = PurchaseState.initial(
         adRemoved: settings.adRemoved,
         aiAccess: settings.aiAccess,
       ) {
    VerifiedEntitlementCache.registerAiTokenRefresher(getAiAccessToken);
    _ready = _initialize();
  }

  final PurchaseGateway _purchase;
  final PurchaseVerifier _verifier;
  final bool _ownsVerifier;
  final PurchaseEntitlementRepository _entitlements;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late final Future<void> _ready;
  Future<String?>? _pendingTokenFetch;
  PurchaseState _state;

  @override
  Future<void> get ready => _ready;

  @override
  PurchaseState get state => _state;

  @override
  bool get adRemoved => _state.adRemoved;

  @override
  bool get aiAccess => _state.aiAccess;

  @override
  bool get busy => _state.busy;

  @override
  bool get restoring => _state.restoring;

  @override
  bool get entitlementResolved => _state.entitlementResolved;

  @override
  bool get canPurchase => _state.canPurchase;

  @override
  bool get canPurchaseAi => _state.canPurchaseAi;

  @override
  String? get statusMessage => _state.statusMessage;

  @override
  String get priceLabel => _state.priceLabel;

  @override
  String get aiPriceLabel => _state.aiPriceLabel;

  @override
  void dispose() {
    VerifiedEntitlementCache.clearAiTokenRefresher();
    VerifiedEntitlementCache.clearAiToken();
    unawaited(_subscription?.cancel());
    if (_ownsVerifier && _verifier is PurchaseVerificationService) {
      (_verifier as PurchaseVerificationService).close();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    _transition(PurchasePhase.restoring, statusMessage: null);
    try {
      final available = await _purchase.isAvailable();
      _replaceState(_state.copyWith(storeAvailable: available));
      if (!available) {
        _transition(
          PurchasePhase.unavailable,
          statusMessage: 'ストアに接続できないため、購入済み情報を確認できません。',
        );
        return;
      }

      _subscription = _purchase.purchaseStream.listen(
        (details) => unawaited(_processPurchases(details)),
        onError: (Object error, StackTrace stackTrace) {
          _transition(
            PurchasePhase.failed,
            statusMessage: '購入情報の受信に失敗しました。',
          );
          if (kDebugMode) {
            debugPrint('PurchaseProvider: stream failed - $error\n$stackTrace');
          }
        },
      );

      await _loadProductDetails();
      await _purchase.restorePurchases();
      await Future<void>.delayed(Duration.zero);
      if (_state.phase == PurchasePhase.restoring) {
        _transition(PurchasePhase.ready);
      }
    } on Object catch (error, stackTrace) {
      _transition(
        PurchasePhase.failed,
        statusMessage: '購入情報の確認に失敗しました。時間をおいてもう一度お試しください。',
      );
      if (kDebugMode) {
        debugPrint('PurchaseProvider: init failed - $error\n$stackTrace');
      }
    }
  }

  Future<void> _processPurchases(List<PurchaseDetails> details) async {
    var handledRelevantPurchase = false;
    for (final purchase in details) {
      if (!_isSupportedProduct(purchase.productID)) continue;
      handledRelevantPurchase = true;
      await _processPurchase(purchase);
    }

    if (handledRelevantPurchase || _state.phase == PurchasePhase.restoring) {
      _transition(PurchasePhase.ready);
    }
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    try {
      switch (purchase.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await _verifyAndApply(purchase);
        case PurchaseStatus.error:
          _setMessage('購入処理でエラーが発生しました。');
        case PurchaseStatus.canceled:
          _setMessage('購入をキャンセルしました。');
        case PurchaseStatus.pending:
          _setMessage('購入処理を確認しています。');
      }
    } on Object catch (error, stackTrace) {
      _setMessage('購入情報を確認できませんでした。通信状態を確認して、もう一度お試しください。');
      if (kDebugMode) {
        debugPrint(
          'PurchaseProvider: processing ${purchase.productID} failed - '
          '$error\n$stackTrace',
        );
      }
    }
  }

  Future<void> _verifyAndApply(PurchaseDetails purchase) async {
    final verification = await _verifier.verify(purchase);
    if (!verification.verified) {
      if (verification.retryable) {
        _setMessage(verification.message ?? '購入情報を確認できませんでした。');
        return;
      }
      await _deny(purchase.productID, verification.message);
      return;
    }

    await _grant(purchase, verification);
    if (!purchase.pendingCompletePurchase) return;

    try {
      await _purchase.completePurchase(purchase);
    } on Object catch (error, stackTrace) {
      _setMessage('購入は確認済みですが、ストア処理を完了できませんでした。再起動後に再試行します。');
      if (kDebugMode) {
        debugPrint(
          'PurchaseProvider: completePurchase failed - $error\n$stackTrace',
        );
      }
    }
  }

  Future<void> _grant(
    PurchaseDetails purchase,
    EntitlementVerification verification,
  ) async {
    final snapshot = await _entitlements.grant(purchase, verification);
    _replaceState(
      _state.copyWith(
        adRemoved: snapshot.adRemoved,
        aiAccess: snapshot.aiAccess,
        statusMessage: null,
      ),
    );
  }

  Future<void> _deny(String productId, String? message) async {
    final snapshot = await _entitlements.deny(productId);
    _replaceState(
      _state.copyWith(
        adRemoved: snapshot.adRemoved,
        aiAccess: snapshot.aiAccess,
        statusMessage: message ?? '購入を確認できませんでした。',
      ),
    );
  }

  @override
  Future<String?> getAiAccessToken() {
    final pending = _pendingTokenFetch;
    if (pending != null) return pending;

    final refresh = _getAiAccessTokenImpl();
    _pendingTokenFetch = refresh;
    return refresh.whenComplete(() {
      if (identical(_pendingTokenFetch, refresh)) {
        _pendingTokenFetch = null;
      }
    });
  }

  Future<String?> _getAiAccessTokenImpl() async {
    final cached = _entitlements.validAiAccessToken(DateTime.now());
    if (cached != null) return cached;

    final purchase = _entitlements.snapshot.aiPurchase;
    if (purchase == null) return null;

    try {
      final verification = await _verifier.verify(purchase);
      if (!verification.verified) {
        if (verification.retryable) {
          _setMessage(verification.message ?? 'AI利用権を更新できませんでした。');
          return null;
        }
        await _deny(PurchaseProvider.aiProductId, verification.message);
        return null;
      }
      if (verification.accessToken == null) {
        await _deny(PurchaseProvider.aiProductId, verification.message);
        return null;
      }
      await _grant(purchase, verification);
      return _entitlements.snapshot.aiAccessToken;
    } on Object catch (error, stackTrace) {
      _setMessage('AI利用権を更新できませんでした。通信状態を確認してください。');
      if (kDebugMode) {
        debugPrint(
          'PurchaseProvider: token refresh failed - $error\n$stackTrace',
        );
      }
      return null;
    }
  }

  @override
  Future<void> purchase() => _purchaseProduct(ai: false);

  @override
  Future<void> purchaseAi() => _purchaseProduct(ai: true);

  Future<void> _purchaseProduct({required bool ai}) async {
    if (_state.phase != PurchasePhase.ready) return;
    _transition(PurchasePhase.purchasing, statusMessage: null);
    try {
      final available = await _purchase.isAvailable();
      _replaceState(_state.copyWith(storeAvailable: available));
      if (!available) {
        _transition(
          PurchasePhase.unavailable,
          statusMessage: 'ストアに接続できないため、購入は現在利用できません。',
        );
        return;
      }

      await _loadProductDetails();
      final product = ai ? _state.aiProduct : _state.adsProduct;
      if (product == null) {
        _transition(
          PurchasePhase.ready,
          statusMessage: '購入アイテムを準備中です。しばらくしてからもう一度お試しください。',
        );
        return;
      }

      final started = await _purchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      _transition(
        PurchasePhase.ready,
        statusMessage: started
            ? null
            : '購入処理を開始できませんでした。時間をおいてもう一度お試しください。',
      );
    } on Object catch (error, stackTrace) {
      _transition(
        PurchasePhase.ready,
        statusMessage: '購入処理を開始できませんでした。時間をおいてもう一度お試しください。',
      );
      if (kDebugMode) {
        debugPrint('PurchaseProvider: purchase failed - $error\n$stackTrace');
      }
    }
  }

  @override
  Future<void> restore() async {
    if (_state.busy) return;
    _transition(PurchasePhase.restoring, statusMessage: null);
    try {
      final available = await _purchase.isAvailable();
      _replaceState(_state.copyWith(storeAvailable: available));
      if (!available) {
        _transition(
          PurchasePhase.unavailable,
          statusMessage: 'ストアに接続できないため、購入は現在利用できません。',
        );
        return;
      }
      await _purchase.restorePurchases();
      await Future<void>.delayed(Duration.zero);
      if (_state.phase == PurchasePhase.restoring) {
        _transition(PurchasePhase.ready);
      }
    } on Object catch (error, stackTrace) {
      _transition(
        PurchasePhase.failed,
        statusMessage: '購入履歴を復元できませんでした。時間をおいてもう一度お試しください。',
      );
      if (kDebugMode) {
        debugPrint('PurchaseProvider: restore failed - $error\n$stackTrace');
      }
    }
  }

  Future<void> _loadProductDetails() async {
    final response = await _purchase.queryProductDetails({
      PurchaseProvider.productId,
      PurchaseProvider.aiProductId,
    });
    ProductDetails? adsProduct;
    ProductDetails? aiProduct;
    for (final product in response.productDetails) {
      if (product.id == PurchaseProvider.productId) {
        adsProduct = product;
      } else if (product.id == PurchaseProvider.aiProductId) {
        aiProduct = product;
      }
    }

    _replaceState(
      _state.copyWith(
        adsProduct: adsProduct,
        aiProduct: aiProduct,
        statusMessage: adsProduct == null && aiProduct == null
            ? '購入アイテムを準備中です。しばらくしてからもう一度お試しください。'
            : null,
      ),
    );
  }

  bool _isSupportedProduct(String productId) =>
      productId == PurchaseProvider.productId ||
      productId == PurchaseProvider.aiProductId;

  void _transition(PurchasePhase phase, {String? statusMessage}) {
    _replaceState(_state.copyWith(phase: phase, statusMessage: statusMessage));
  }

  void _setMessage(String? message) {
    _replaceState(_state.copyWith(statusMessage: message));
  }

  void _replaceState(PurchaseState next) {
    _state = next;
    notifyListeners();
  }
}
