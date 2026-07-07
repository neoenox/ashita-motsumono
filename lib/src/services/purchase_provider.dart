// lib/src/services/purchase_provider.dart
// 広告除去の購入状態を管理する ChangeNotifier。
// 関連: ad_service.dart, app_settings.dart, main.dart, settings_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_settings.dart';

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
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    return _purchase.queryProductDetails(identifiers);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _purchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> restorePurchases() => _purchase.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _purchase.completePurchase(purchase);
  }
}

class PurchaseProvider extends ChangeNotifier {
  PurchaseProvider(this._settings, {PurchaseGateway? gateway})
    : _purchase = gateway ?? InAppPurchaseGateway() {
    _ready = _init();
  }

  final AppSettings _settings;
  final PurchaseGateway _purchase;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late final Future<void> _ready;
  Future<void> get ready => _ready;

  static const productId = String.fromEnvironment(
    'IAP_REMOVE_ADS_PRODUCT_ID',
    defaultValue: 'remove_ads',
  );

  bool _adRemoved = false;
  bool get adRemoved => _adRemoved;

  bool _busy = false;
  bool get busy => _busy;

  String? _storePrice;
  String get priceLabel =>
      _storePrice == null ? '価格は購入前に表示' : '買い切り $_storePrice';

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _adRemoved = _settings.adRemoved;
      final available = await _purchase.isAvailable();
      if (!available) return;
      _subscription = _purchase.purchaseStream.listen(_onPurchase);
      await _loadProductDetails();
      unawaited(_purchase.restorePurchases());
    } on Object catch (e) {
      if (kDebugMode) debugPrint('PurchaseProvider: init failed - $e');
    }
  }

  void _onPurchase(List<PurchaseDetails> details) {
    for (final purchase in details) {
      if (purchase.productID != productId) continue;
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
      final product = await _loadProductDetails();
      if (product == null) return;
      await _purchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final available = await _purchase.isAvailable();
      if (!available) return;
      await _purchase.restorePurchases();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<ProductDetails?> _loadProductDetails() async {
    final productDetails = await _purchase.queryProductDetails({productId});
    final product = productDetails.productDetails.firstOrNull;
    if (product != null) {
      _storePrice = product.price;
      notifyListeners();
    }
    return product;
  }
}
