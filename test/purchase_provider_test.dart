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

  test('reports unavailable store before purchase', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway(available: false);

    final provider = PurchaseProvider(settings, gateway: gateway);
    await provider.ready;

    expect(provider.canPurchase, isFalse);
    expect(provider.statusMessage, 'ストアに接続できないため、購入は現在利用できません。');

    await provider.purchase();

    expect(gateway.buyCount, 0);
  });

  test('reports missing store product before purchase', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway(
      notFoundIDs: [PurchaseProvider.productId],
    );

    final provider = PurchaseProvider(settings, gateway: gateway);
    await provider.ready;

    expect(provider.canPurchase, isFalse);
    expect(provider.statusMessage, '購入アイテムを準備中です。しばらくしてからもう一度お試しください。');

    await provider.purchase();

    expect(gateway.buyCount, 0);
  });
}

class _FakePurchaseGateway implements PurchaseGateway {
  _FakePurchaseGateway({
    this.available = true,
    this.productDetails = const [],
    this.notFoundIDs = const [],
  });

  final bool available;
  final List<ProductDetails> productDetails;
  final List<String> notFoundIDs;
  final List<Set<String>> queriedIds = [];
  int restoreCount = 0;
  int buyCount = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queriedIds.add(Set<String>.from(ids));
    return ProductDetailsResponse(
      productDetails: productDetails,
      notFoundIDs: notFoundIDs,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCount += 1;
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCount += 1;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
