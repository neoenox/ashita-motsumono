import 'package:in_app_purchase/in_app_purchase.dart';

abstract interface class PurchaseGateway {
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
