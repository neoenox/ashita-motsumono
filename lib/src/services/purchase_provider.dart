// lib/src/services/purchase_provider.dart
// 広告除去の購入状態を管理する ChangeNotifier。
// 関連: ad_service.dart, app_settings.dart, main.dart, settings_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_settings.dart';

class PurchaseProvider extends ChangeNotifier {
  PurchaseProvider(this._settings) {
    try {
      _init();
    } catch (_) {
      // InAppPurchase が利用できない環境でもクラッシュさせない
    }
  }

  final AppSettings _settings;
  final InAppPurchase _purchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const _productId = 'remove_ads';

  bool _adRemoved = false;
  bool get adRemoved => _adRemoved;

  bool _busy = false;
  bool get busy => _busy;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _adRemoved = _settings.adRemoved;
    final available = await _purchase.isAvailable();
    if (!available) return;
    _subscription = _purchase.purchaseStream.listen(_onPurchase);
    unawaited(_purchase.restorePurchases());
  }

  void _onPurchase(List<PurchaseDetails> details) {
    for (final purchase in details) {
      if (purchase.productID != _productId) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          _adRemoved = true;
          unawaited(_settings.setAdRemoved(true));
          if (purchase.pendingCompletePurchase) {
            unawaited(_purchase.completePurchase(purchase));
          }
        case PurchaseStatus.error:
          if (kDebugMode) debugPrint('Purchase error: ${purchase.error}');
        case PurchaseStatus.canceled:
          // ユーザーがキャンセルした場合は何もしない
        case PurchaseStatus.pending:
          // 決済処理中は待機
      }
      notifyListeners();
    }
  }

  Future<void> purchase() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final available = await _purchase.isAvailable();
      if (!available) return;
      final productDetails = await _purchase.queryProductDetails({_productId});
      final product = productDetails.productDetails.firstOrNull;
      if (product == null) return;
      await _purchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
