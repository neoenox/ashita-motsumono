import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_settings.dart';
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
    this._settings, {
    PurchaseGateway? gateway,
    PurchaseVerifier? verifier,
  })  : _purchase = gateway ?? InAppPurchaseGateway(),
        _verifier = verifier ?? PurchaseVerificationService() {
    VerifiedEntitlementCache.registerAiTokenRefresher(getAiAccessToken);
    _ready = _init();
  }

  final AppSettings _settings;
  final PurchaseGateway _purchase;
  final PurchaseVerifier _verifier;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late final Future<void> _ready;

  bool _adRemoved = false;
  bool _aiAccess = false;
  bool _busy = false;
  bool _storeAvailable = false;
  bool _productLoaded = false;
  bool _aiProductLoaded = false;
  String? _statusMessage;
  ProductDetails? _adsProduct;
  ProductDetails? _aiProduct;
  String? _storePrice;
  String? _aiStorePrice;
  PurchaseDetails? _aiPurchase;
  String? _aiAccessToken;
  DateTime? _aiAccessTokenExpiresAt;

  @override
  Future<void> get ready => _ready;
  @override
  bool get adRemoved => _adRemoved;
  @override
  bool get aiAccess => _aiAccess;
  @override
  bool get busy => _busy;
  @override
  bool get canPurchase => _storeAvailable && _productLoaded && !_busy;
  @override
  bool get canPurchaseAi => _storeAvailable && _aiProductLoaded && !_busy;
  @override
  String? get statusMessage => _statusMessage;
  @override
  String get priceLabel =>
      _storePrice == null ? '価格は購入前に表示' : '買い切り $_storePrice';
  @override
  String get aiPriceLabel =>
      _aiStorePrice == null ? '価格は購入前に表示' : '買い切り $_aiStorePrice';

  @override
  void dispose() {
    VerifiedEntitlementCache.clearAiTokenRefresher();
    VerifiedEntitlementCache.clearAiToken();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _init() async {
    try {
      // 端末内フラグだけでは権利を付与せず、毎回ストア復元とサーバー検証を行う。
      _adRemoved = false;
      _aiAccess = false;
      _storeAvailable = await _purchase.isAvailable();
      if (!_storeAvailable) {
        _statusMessage = 'ストアに接続できないため、購入済み情報を確認できません。';
        notifyListeners();
        return;
      }
      _subscription = _purchase.purchaseStream.listen(
        (details) => unawaited(_processPurchases(details)),
        onError: (Object error, StackTrace stackTrace) {
          _statusMessage = '購入情報の受信に失敗しました。';
          notifyListeners();
          if (kDebugMode) {
            debugPrint('PurchaseProvider: stream failed - $error\n$stackTrace');
          }
        },
      );
      await _loadProductDetails();
      await _purchase.restorePurchases();
    } on Object catch (error, stackTrace) {
      _statusMessage = '購入情報の確認に失敗しました。時間をおいてもう一度お試しください。';
      notifyListeners();
      if (kDebugMode) {
        debugPrint('PurchaseProvider: init failed - $error\n$stackTrace');
      }
    }
  }

  Future<void> _processPurchases(List<PurchaseDetails> details) async {
    for (final purchase in details) {
      if (purchase.productID != PurchaseProvider.productId &&
          purchase.productID != PurchaseProvider.aiProductId) {
        continue;
      }
      await _processPurchaseSafely(purchase);
    }
  }

  Future<void> _processPurchaseSafely(PurchaseDetails purchase) async {
    try {
      switch (purchase.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          final verification = await _verifier.verify(purchase);
          if (!verification.verified) {
            await _deny(purchase.productID, verification.message);
            break;
          }

          await _grant(purchase, verification);
          if (purchase.pendingCompletePurchase) {
            try {
              await _purchase.completePurchase(purchase);
            } on Object catch (error, stackTrace) {
              // ストアから再配信されたときに再試行できるよう、検証済み権利は維持する。
              _statusMessage = '購入は確認済みですが、ストア処理を完了できませんでした。再起動後に再試行します。';
              if (kDebugMode) {
                debugPrint(
                  'PurchaseProvider: completePurchase failed - '
                  '$error\n$stackTrace',
                );
              }
            }
          }
        case PurchaseStatus.error:
          _statusMessage = '購入処理でエラーが発生しました。';
        case PurchaseStatus.canceled:
          _statusMessage = '購入をキャンセルしました。';
        case PurchaseStatus.pending:
          _statusMessage = '購入処理を確認しています。';
      }
    } on Object catch (error, stackTrace) {
      _statusMessage = '購入情報を確認できませんでした。通信状態を確認して、もう一度お試しください。';
      if (kDebugMode) {
        debugPrint(
          'PurchaseProvider: processing ${purchase.productID} failed - '
          '$error\n$stackTrace',
        );
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> _grant(
    PurchaseDetails purchase,
    EntitlementVerification verification,
  ) async {
    if (purchase.productID == PurchaseProvider.productId) {
      await _settings.setAdRemoved(true);
      _adRemoved = true;
      _statusMessage = null;
      return;
    }

    await _settings.setAiAccess(true);
    _aiAccess = true;
    _aiPurchase = purchase;
    _aiAccessToken = verification.accessToken;
    _aiAccessTokenExpiresAt = verification.expiresAt;
    _statusMessage = null;
  }

  Future<void> _deny(String productId, String? message) async {
    _statusMessage = message ?? '購入を確認できませんでした。';
    if (productId == PurchaseProvider.productId) {
      await _settings.setAdRemoved(false);
      _adRemoved = false;
      return;
    }

    await _settings.setAiAccess(false);
    _aiAccess = false;
    _aiPurchase = null;
    _aiAccessToken = null;
    _aiAccessTokenExpiresAt = null;
    VerifiedEntitlementCache.clearAiToken();
  }

  @override
  Future<String?> getAiAccessToken() async {
    final expiry = _aiAccessTokenExpiresAt;
    if (_aiAccess &&
        _aiAccessToken != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 30)))) {
      return _aiAccessToken;
    }

    final purchase = _aiPurchase;
    if (purchase == null) return null;
    try {
      final verification = await _verifier.verify(purchase);
      if (!verification.verified || verification.accessToken == null) {
        await _deny(PurchaseProvider.aiProductId, verification.message);
        notifyListeners();
        return null;
      }
      await _grant(purchase, verification);
      notifyListeners();
      return _aiAccessToken;
    } on Object catch (error, stackTrace) {
      _statusMessage = 'AI利用権を更新できませんでした。通信状態を確認してください。';
      notifyListeners();
      if (kDebugMode) {
        debugPrint('PurchaseProvider: token refresh failed - $error\n$stackTrace');
      }
      return null;
    }
  }

  @override
  Future<void> purchase() => _purchaseProduct(ai: false);
  @override
  Future<void> purchaseAi() => _purchaseProduct(ai: true);

  Future<void> _purchaseProduct({required bool ai}) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      _storeAvailable = await _purchase.isAvailable();
      if (!_storeAvailable) {
        _statusMessage = 'ストアに接続できないため、購入は現在利用できません。';
        return;
      }
      await _loadProductDetails();
      final product = ai ? _aiProduct : _adsProduct;
      if (product == null) return;
      final started = await _purchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _statusMessage = '購入処理を開始できませんでした。時間をおいてもう一度お試しください。';
      }
    } on Object catch (error, stackTrace) {
      _statusMessage = '購入処理を開始できませんでした。時間をおいてもう一度お試しください。';
      if (kDebugMode) {
        debugPrint('PurchaseProvider: purchase failed - $error\n$stackTrace');
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> restore() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      _storeAvailable = await _purchase.isAvailable();
      if (!_storeAvailable) {
        _statusMessage = 'ストアに接続できないため、購入は現在利用できません。';
        return;
      }
      await _purchase.restorePurchases();
    } on Object catch (error, stackTrace) {
      _statusMessage = '購入履歴を復元できませんでした。時間をおいてもう一度お試しください。';
      if (kDebugMode) {
        debugPrint('PurchaseProvider: restore failed - $error\n$stackTrace');
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<ProductDetails?> _loadProductDetails() async {
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
    _adsProduct = adsProduct;
    _aiProduct = aiProduct;
    _productLoaded = adsProduct != null;
    _aiProductLoaded = aiProduct != null;
    _storePrice = adsProduct?.price;
    _aiStorePrice = aiProduct?.price;
    _statusMessage = !_productLoaded && !_aiProductLoaded
        ? '購入アイテムを準備中です。しばらくしてからもう一度お試しください。'
        : null;
    notifyListeners();
    return adsProduct;
  }
}
