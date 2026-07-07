// test/purchase_provider_test.dart
// PurchaseProvider がストア商品情報を正しく UI 表示へ反映することを検証する。
// 関連: lib/src/services/purchase_provider.dart, lib/src/screens/settings_screen.dart

import 'dart:async';

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads store product price into price label', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway(
      productDetails: [
        ProductDetails(
          id: PurchaseProvider.productId,
          title: '広告非表示',
          description: '広告を非表示にします',
          price: '¥240',
          rawPrice: 240,
          currencyCode: 'JPY',
          currencySymbol: '¥',
        ),
      ],
    );

    final provider = PurchaseProvider(settings, gateway: gateway);
    await provider.ready;

    expect(provider.priceLabel, '買い切り ¥240');
    expect(gateway.queriedIds, [
      {PurchaseProvider.productId},
    ]);
    expect(gateway.restoreCount, 1);
  });
}

class _FakePurchaseGateway implements PurchaseGateway {
  _FakePurchaseGateway({this.productDetails = const []});

  final List<ProductDetails> productDetails;
  final List<Set<String>> queriedIds = [];
  int restoreCount = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queriedIds.add(Set<String>.from(ids));
    return ProductDetailsResponse(
      productDetails: productDetails,
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCount += 1;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
