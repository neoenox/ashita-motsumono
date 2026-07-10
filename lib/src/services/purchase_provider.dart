// lib/src/services/purchase_provider.dart
// 広告除去・AI分析の購入状態を管理する ChangeNotifier。
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

  bool _aiAccess = false;
  @override
  bool get aiAccess => _aiAccess;

  bool _busy = false;
  @override
  bool get busy => _busy;

  bool _storeAvailable = false;
  bool _productLoaded = false;
  String? _statusMessage;
  @override
  bool get canPurchase => _storeAvailable && _productLoaded && !_busy;

  bool _aiProductLoaded = false;
  @override
  bool get canPurchaseAi => _storeAvailable && _aiProductLoaded && !_busy;

  @override
  String? get statusMessage => _statusMessage;

  String? _storePrice;
  @override
  String get priceLabel =>
      _storePrice == null ? '価格は購入前に表示' : '買い切り $_storePrice';

  String? _aiStorePrice;
  @override
  String get aiPriceLabel =>
      _aiStorePrice == null ? '価格は購入前に表示' : '買い切り $_aiStorePrice';

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _adRemoved = _settings.adRemoved;
      _aiAccess = _settings.aiAccess;
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
      switch (purchase.productID) {
        case PurchaseProvider.productId:
          _handleAdPurchase(purchase);
        case PurchaseProvider.aiProductId:
          _handleAiPurchase(purchase);
      }
      notifyListeners();
    }
  }

  void _handleAdPurchase(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased || PurchaseStatus.restored:
        _adRemoved = true;
        unawaited(_settings.setAdRemoved(true));
        if (purchase.pendingCompletePurchase) {
          unawaited(_purchase.completePurchase(purchase));
        }
      case PurchaseStatus.error:
        if (kDebugMode) debugPrint('Ad purchase error: ${purchase.error}');
      case PurchaseStatus.canceled:
      case PurchaseStatus.pending:
    }
  }

  void _handleAiPurchase(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased || PurchaseStatus.restored:
        _aiAccess = true;
        unawaited(_settings.setAiAccess(true));
        if (purchase.pendingCompletePurchase) {
          unawaited(_purchase.completePurchase(purchase));
        }
      case PurchaseStatus.error:
        if (kDebugMode) debugPrint('AI purchase error: ${purchase.error}');
      case PurchaseStatus.canceled:
      case PurchaseStatus.pending:
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
  Future<void> purchaseAi() async {
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
    final productDetails = await _purchase.queryProductDetails({
      PurchaseProvider.productId,
      PurchaseProvider.aiProductId,
    });
    ProductDetails? adsProduct;
    ProductDetails? aiProduct;
    for (final p in productDetails.productDetails) {
      if (p.id == PurchaseProvider.productId) {
        adsProduct = p;
      } else if (p.id == PurchaseProvider.aiProductId) {
        aiProduct = p;
      }
    }
    _productLoaded = adsProduct != null;
    if (adsProduct != null) {
      _storePrice = adsProduct.price;
    }
    _aiProductLoaded = aiProduct != null;
    if (aiProduct != null) {
      _aiStorePrice = aiProduct.price;
    }
    if (!_productLoaded && !_aiProductLoaded) {
      _statusMessage = '購入アイテムを準備中です。しばらくしてからもう一度お試しください。';
    } else {
      _statusMessage = null;
    }
    notifyListeners();
    return adsProduct;
  }
}
