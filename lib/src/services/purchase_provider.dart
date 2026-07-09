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

abstract class PurchaseProvider extends ChangeNotifier {
  bool get adRemoved;
  bool get busy;
  String get priceLabel;
  bool get canPurchase;
  String? get statusMessage;
  Future<void> get ready;

  static const productId = String.fromEnvironment(
    'IAP_REMOVE_ADS_PRODUCT_ID',
    defaultValue: 'remove_ads',
  );

  Future<void> purchase();
  Future<void> restore();
}

class AppPurchaseProvider extends PurchaseProvider {
  AppPurchaseProvider(this._settings, {PurchaseGateway? gateway})
    : _purchase = gateway ?? InAppPurchaseGateway() {
    _ready = _init();
  }

  final AppSettings _settings;
  final PurchaseGateway _purchase;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late final Future<void> _ready;
  @override
  Future<void> get ready => _ready;

  bool _adRemoved = false;
  @override
  bool get adRemoved => _adRemoved;

  bool _busy = false;
  @override
  bool get busy => _busy;

  bool _storeAvailable = false;
  bool _productLoaded = false;
  String? _statusMessage;
  @override
  bool get canPurchase => _storeAvailable && _productLoaded && !_busy;
  @override
  String? get statusMessage => _statusMessage;

  String? _storePrice;
  @override
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
      _storeAvailable = available;
      if (!available) {
        _statusMessage = 'ストアに接続できないため、購入は現在利用できません。';
        notifyListeners();
        return;
      }
      _subscription = _purchase.purchaseStream.listen(_onPurchase);
      await _loadProductDetails();
      unawaited(_purchase.restorePurchases());
    } on Object catch (e) {
      _statusMessage = '購入情報の確認に失敗しました。時間をおいてもう一度お試しください。';
      notifyListeners();
      if (kDebugMode) debugPrint('PurchaseProvider: init failed - $e');
    }
  }

  void _onPurchase(List<PurchaseDetails> details) {
    for (final purchase in details) {
      if (purchase.productID != PurchaseProvider.productId) continue;
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

  @override
  Future<void> purchase() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final available = await _purchase.isAvailable();
      _storeAvailable = available;
      if (!available) {
        _statusMessage = 'ストアに接続できないため、購入は現在利用できません。';
        return;
      }
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

  @override
  Future<void> restore() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final available = await _purchase.isAvailable();
      _storeAvailable = available;
      if (!available) {
        _statusMessage = 'ストアに接続できないため、購入は現在利用できません。';
        return;
      }
      await _purchase.restorePurchases();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<ProductDetails?> _loadProductDetails() async {
      final productDetails = await _purchase.queryProductDetails({PurchaseProvider.productId});
    final product = productDetails.productDetails.firstOrNull;
    if (product != null) {
      _storePrice = product.price;
      _productLoaded = true;
      _statusMessage = null;
      notifyListeners();
    } else {
      _productLoaded = false;
      _statusMessage = '購入アイテムを準備中です。しばらくしてからもう一度お試しください。';
      notifyListeners();
    }
    return product;
  }
}
