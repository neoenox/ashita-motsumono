import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_settings.dart';
import 'purchase_entitlement_repository.dart';
import 'purchase_event_queue.dart';
import 'purchase_gateway.dart';
import 'purchase_state.dart';
import 'purchase_verification_service.dart';
import 'verified_entitlement_cache.dart';

/// ストア・復元・検証イベントを直列化し、購入状態を一元管理する。
class PurchaseCoordinator extends ChangeNotifier {
  PurchaseCoordinator({
    required AppSettings settings,
    required PurchaseGateway gateway,
    required PurchaseVerifier verifier,
    required bool ownsVerifier,
    required String removeAdsProductId,
    required String aiAccessProductId,
  }) : _purchase = gateway,
       _verifier = verifier,
       _ownsVerifier = ownsVerifier,
       _removeAdsProductId = removeAdsProductId,
       _aiAccessProductId = aiAccessProductId,
       _entitlements = PurchaseEntitlementRepository(
         settings,
         removeAdsProductId: removeAdsProductId,
         aiAccessProductId: aiAccessProductId,
       ),
       _state = PurchaseState.initial(
         adRemoved: settings.adRemoved,
         aiAccess: settings.aiAccess,
       ) {
    VerifiedEntitlementCache.registerAiTokenRefresher(getAiAccessToken);
    _subscription = _purchase.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: _onPurchaseStreamError,
    );
    final initialization = _events.enqueue(_initialize);
    _ready = initialization.then((_) async {
      await Future<void>.delayed(Duration.zero);
      await _events.enqueue(_finishRestore);
    });
  }

  final PurchaseGateway _purchase;
  final PurchaseVerifier _verifier;
  final bool _ownsVerifier;
  final String _removeAdsProductId;
  final String _aiAccessProductId;
  final PurchaseEntitlementRepository _entitlements;
  final PurchaseEventQueue _events = PurchaseEventQueue();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late final Future<void> _ready;
  Future<String?>? _pendingTokenFetch;
  PurchaseState _state;
  bool _disposed = false;

  PurchaseState get state => _state;
  Future<void> get ready => _ready;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    VerifiedEntitlementCache.clearAiTokenRefresher();
    VerifiedEntitlementCache.clearAiToken();
    unawaited(_subscription?.cancel());
    if (_ownsVerifier && _verifier is PurchaseVerificationService) {
      (_verifier as PurchaseVerificationService).close();
    }
    super.dispose();
  }

  Future<void> purchase(String productId) {
    if (_disposed) return Future<void>.value();
    if (!_isSupportedProduct(productId)) {
      return Future<void>.error(
        UnsupportedError('Unsupported purchase product: $productId'),
      );
    }
    return _events.enqueue(() => _purchaseProduct(productId));
  }

  Future<void> restore() {
    if (_disposed) return Future<void>.value();
    final restore = _events.enqueueValue(_restoreImpl);
    return restore.then((started) async {
      if (!started) return;
      await Future<void>.delayed(Duration.zero);
      await _events.enqueue(_finishRestore);
    });
  }

  Future<String?> getAiAccessToken() {
    final pending = _pendingTokenFetch;
    if (pending != null) return pending;

    final refresh = _events.enqueueValue(_getAiAccessTokenImpl);
    _pendingTokenFetch = refresh;
    return refresh.whenComplete(() {
      if (identical(_pendingTokenFetch, refresh)) {
        _pendingTokenFetch = null;
      }
    });
  }

  Future<void> _initialize() async {
    if (_disposed) return;
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

      await _loadProductDetails();
      await _purchase.restorePurchases();
    } on Object catch (error, stackTrace) {
      _transition(
        PurchasePhase.failed,
        statusMessage: '購入情報の確認に失敗しました。時間をおいてもう一度お試しください。',
      );
      if (kDebugMode) {
        debugPrint('PurchaseCoordinator: init failed - $error\n$stackTrace');
      }
    }
  }

  void _onPurchaseUpdates(List<PurchaseDetails> details) {
    unawaited(_enqueuePurchaseUpdates(details));
  }

  Future<void> _enqueuePurchaseUpdates(List<PurchaseDetails> details) async {
    try {
      await _events.enqueue(() async {
        if (_disposed) return;
        await _processPurchases(details);
      });
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'PurchaseCoordinator: queued purchase processing failed - '
          '$error\n$stackTrace',
        );
      }
    }
  }

  void _onPurchaseStreamError(Object error, StackTrace stackTrace) {
    unawaited(_enqueuePurchaseStreamError(error, stackTrace));
  }

  Future<void> _enqueuePurchaseStreamError(
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      await _events.enqueue(() {
        if (_disposed) return;
        _transition(
          PurchasePhase.failed,
          statusMessage: '購入情報の受信に失敗しました。',
        );
        if (kDebugMode) {
          debugPrint(
            'PurchaseCoordinator: stream failed - $error\n$stackTrace',
          );
        }
      });
    } on Object catch (queueError, queueStackTrace) {
      if (kDebugMode) {
        debugPrint(
          'PurchaseCoordinator: stream error handling failed - '
          '$queueError\n$queueStackTrace',
        );
      }
    }
  }

  void _finishRestore() {
    if (_disposed) return;
    if (_state.phase == PurchasePhase.restoring) {
      _transition(PurchasePhase.ready);
    }
  }

  Future<void> _processPurchases(List<PurchaseDetails> details) async {
    for (final purchase in details) {
      if (!_isSupportedProduct(purchase.productID)) continue;
      await _processPurchase(purchase);
    }
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.purchased || PurchaseStatus.restored:
        final generation = _beginOperation(
          purchase.productID,
          PurchaseOperationPhase.verifying,
          statusMessage: null,
        );
        try {
          await _verifyAndApply(purchase, generation);
        } on Object catch (error, stackTrace) {
          _updateOperation(
            purchase.productID,
            generation,
            PurchaseOperationPhase.failed,
            statusMessage: '購入情報を確認できませんでした。通信状態を確認して、もう一度お試しください。',
          );
          if (kDebugMode) {
            debugPrint(
              'PurchaseCoordinator: processing ${purchase.productID} failed - '
              '$error\n$stackTrace',
            );
          }
        }
      case PurchaseStatus.error:
        _beginOperation(
          purchase.productID,
          PurchaseOperationPhase.failed,
          statusMessage: '購入処理でエラーが発生しました。',
        );
      case PurchaseStatus.canceled:
        _beginOperation(
          purchase.productID,
          PurchaseOperationPhase.canceled,
          statusMessage: '購入をキャンセルしました。',
        );
      case PurchaseStatus.pending:
        final current = _state.operationFor(purchase.productID);
        if (current.busy) {
          _updateOperation(
            purchase.productID,
            current.generation,
            PurchaseOperationPhase.pending,
            statusMessage: '購入処理を確認しています。',
          );
        } else {
          _beginOperation(
            purchase.productID,
            PurchaseOperationPhase.pending,
            statusMessage: '購入処理を確認しています。',
          );
        }
    }
  }

  Future<void> _verifyAndApply(
    PurchaseDetails purchase,
    int generation,
  ) async {
    final verification = await _verifier.verify(purchase);
    if (!_isCurrentOperation(purchase.productID, generation)) return;

    if (!verification.verified) {
      if (verification.retryable) {
        _updateOperation(
          purchase.productID,
          generation,
          PurchaseOperationPhase.retryable,
          statusMessage: verification.message ?? '購入情報を確認できませんでした。',
        );
        return;
      }
      await _deny(purchase.productID);
      if (!_isCurrentOperation(purchase.productID, generation)) return;
      _updateOperation(
        purchase.productID,
        generation,
        PurchaseOperationPhase.denied,
        statusMessage: verification.message ?? '購入を確認できませんでした。',
      );
      return;
    }

    await _grant(purchase, verification);
    if (!_isCurrentOperation(purchase.productID, generation)) return;

    if (purchase.pendingCompletePurchase) {
      _updateOperation(
        purchase.productID,
        generation,
        PurchaseOperationPhase.completing,
        statusMessage: null,
      );
      try {
        await _purchase.completePurchase(purchase);
      } on Object catch (error, stackTrace) {
        _updateOperation(
          purchase.productID,
          generation,
          PurchaseOperationPhase.failed,
          statusMessage: '購入は確認済みですが、ストア処理を完了できませんでした。再起動後に再試行します。',
        );
        if (kDebugMode) {
          debugPrint(
            'PurchaseCoordinator: completePurchase failed - '
            '$error\n$stackTrace',
          );
        }
        return;
      }
    }

    _updateOperation(
      purchase.productID,
      generation,
      PurchaseOperationPhase.succeeded,
      statusMessage: null,
    );
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
      ),
    );
  }

  Future<void> _deny(String productId) async {
    final snapshot = await _entitlements.deny(productId);
    _replaceState(
      _state.copyWith(
        adRemoved: snapshot.adRemoved,
        aiAccess: snapshot.aiAccess,
      ),
    );
  }

  Future<String?> _getAiAccessTokenImpl() async {
    if (_disposed) return null;
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
        await _deny(_aiAccessProductId);
        _setMessage(verification.message ?? 'AI利用権を確認できませんでした。');
        return null;
      }
      if (verification.accessToken == null || verification.expiresAt == null) {
        await _deny(_aiAccessProductId);
        _setMessage(verification.message ?? 'AI利用権トークンを確認できませんでした。');
        return null;
      }
      await _grant(purchase, verification);
      _setMessage(null);
      return _entitlements.snapshot.aiAccessToken;
    } on Object catch (error, stackTrace) {
      _setMessage('AI利用権を更新できませんでした。通信状態を確認してください。');
      if (kDebugMode) {
        debugPrint(
          'PurchaseCoordinator: token refresh failed - $error\n$stackTrace',
        );
      }
      return null;
    }
  }

  Future<void> _purchaseProduct(String productId) async {
    final currentOperation = _state.operationFor(productId);
    if (_state.phase != PurchasePhase.ready ||
        _state.hasActiveOperation ||
        currentOperation.busy) {
      return;
    }

    final generation = _beginOperation(
      productId,
      PurchaseOperationPhase.launching,
      statusMessage: null,
    );
    _transition(PurchasePhase.purchasing, statusMessage: null);
    try {
      final available = await _purchase.isAvailable();
      _replaceState(_state.copyWith(storeAvailable: available));
      if (!available) {
        _updateOperation(
          productId,
          generation,
          PurchaseOperationPhase.failed,
          statusMessage: 'ストアに接続できないため、購入は現在利用できません。',
        );
        _transition(
          PurchasePhase.unavailable,
          statusMessage: 'ストアに接続できないため、購入は現在利用できません。',
        );
        return;
      }

      await _loadProductDetails();
      final product = productId == _aiAccessProductId
          ? _state.aiProduct
          : _state.adsProduct;
      if (product == null) {
        const message = '購入アイテムを準備中です。しばらくしてからもう一度お試しください。';
        _updateOperation(
          productId,
          generation,
          PurchaseOperationPhase.failed,
          statusMessage: message,
        );
        _transition(PurchasePhase.ready, statusMessage: message);
        return;
      }

      final started = await _purchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (started) {
        _updateOperation(
          productId,
          generation,
          PurchaseOperationPhase.pending,
          statusMessage: null,
        );
        _transition(PurchasePhase.ready, statusMessage: null);
      } else {
        const message = '購入処理を開始できませんでした。時間をおいてもう一度お試しください。';
        _updateOperation(
          productId,
          generation,
          PurchaseOperationPhase.failed,
          statusMessage: message,
        );
        _transition(PurchasePhase.ready, statusMessage: message);
      }
    } on Object catch (error, stackTrace) {
      const message = '購入処理を開始できませんでした。時間をおいてもう一度お試しください。';
      _updateOperation(
        productId,
        generation,
        PurchaseOperationPhase.failed,
        statusMessage: message,
      );
      if (_state.phase == PurchasePhase.purchasing) {
        _transition(PurchasePhase.ready, statusMessage: message);
      }
      if (kDebugMode) {
        debugPrint(
          'PurchaseCoordinator: purchase failed - $error\n$stackTrace',
        );
      }
    }
  }

  Future<bool> _restoreImpl() async {
    if (_state.busy) return false;
    _transition(PurchasePhase.restoring, statusMessage: null);
    try {
      final available = await _purchase.isAvailable();
      _replaceState(_state.copyWith(storeAvailable: available));
      if (!available) {
        _transition(
          PurchasePhase.unavailable,
          statusMessage: 'ストアに接続できないため、購入は現在利用できません。',
        );
        return false;
      }
      await _purchase.restorePurchases();
      return true;
    } on Object catch (error, stackTrace) {
      _transition(
        PurchasePhase.failed,
        statusMessage: '購入履歴を復元できませんでした。時間をおいてもう一度お試しください。',
      );
      if (kDebugMode) {
        debugPrint(
          'PurchaseCoordinator: restore failed - $error\n$stackTrace',
        );
      }
      return false;
    }
  }

  Future<void> _loadProductDetails() async {
    final response = await _purchase.queryProductDetails({
      _removeAdsProductId,
      _aiAccessProductId,
    });
    ProductDetails? adsProduct;
    ProductDetails? aiProduct;
    for (final product in response.productDetails) {
      if (product.id == _removeAdsProductId) {
        adsProduct = product;
      } else if (product.id == _aiAccessProductId) {
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
      productId == _removeAdsProductId || productId == _aiAccessProductId;

  int _beginOperation(
    String productId,
    PurchaseOperationPhase phase, {
    required String? statusMessage,
  }) {
    final current = _state.operationFor(productId);
    final generation = current.generation + 1;
    _replaceState(
      _state.withOperation(
        productId,
        PurchaseOperationState(
          phase: phase,
          generation: generation,
          statusMessage: statusMessage,
        ),
        statusMessage: statusMessage,
      ),
    );
    return generation;
  }

  void _updateOperation(
    String productId,
    int generation,
    PurchaseOperationPhase phase, {
    required String? statusMessage,
  }) {
    if (!_isCurrentOperation(productId, generation)) return;
    final current = _state.operationFor(productId);
    _replaceState(
      _state.withOperation(
        productId,
        current.copyWith(phase: phase, statusMessage: statusMessage),
        statusMessage: statusMessage,
      ),
    );
  }

  bool _isCurrentOperation(String productId, int generation) =>
      _state.operationFor(productId).generation == generation;

  void _transition(PurchasePhase phase, {String? statusMessage}) {
    _replaceState(_state.transitionTo(phase, statusMessage: statusMessage));
  }

  void _setMessage(String? message) {
    _replaceState(_state.copyWith(statusMessage: message));
  }

  void _replaceState(PurchaseState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
