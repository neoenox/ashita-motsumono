import 'dart:async';

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:ashita_motsumono/src/services/purchase_verification_service.dart';
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
    final provider = AppPurchaseProvider(settings, gateway: gateway);
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);

    await provider.ready;

    expect(provider.priceLabel, '買い切り ¥240');
    expect(gateway.queriedIds, [
      {PurchaseProvider.productId, PurchaseProvider.aiProductId},
    ]);
    expect(gateway.restoreCount, 1);
  });

  test('reports unavailable store before purchase', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway(available: false);
    final provider = AppPurchaseProvider(settings, gateway: gateway);
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);

    await provider.ready;

    expect(provider.canPurchase, isFalse);
    expect(provider.statusMessage, 'ストアに接続できないため、購入済み情報を確認できません。');

    await provider.purchase();
    expect(gateway.buyCount, 0);
  });

  test('reports missing store product before purchase', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway(
      notFoundIDs: [PurchaseProvider.productId],
    );
    final provider = AppPurchaseProvider(settings, gateway: gateway);
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);

    await provider.ready;

    expect(provider.canPurchase, isFalse);
    expect(provider.statusMessage, '購入アイテムを準備中です。しばらくしてからもう一度お試しください。');

    await provider.purchase();
    expect(gateway.buyCount, 0);
  });

  test('grants AI access and completes only after verification', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway();
    final verifier = _FakeVerifier(_grantedAiVerification());
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    final purchase = _purchase(PurchaseProvider.aiProductId);
    gateway.emit([purchase]);
    await gateway.purchaseCompleted.future;

    expect(verifier.verifiedProductIds, [PurchaseProvider.aiProductId]);
    expect(provider.aiAccess, isTrue);
    expect(gateway.completedPurchases, [purchase]);
  });

  test('does not grant or complete an unverified purchase', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway();
    final verifier = _FakeVerifier(
      const EntitlementVerification.denied('verification failed'),
    );
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    gateway.emit([_purchase(PurchaseProvider.aiProductId)]);
    await verifier.called.future;
    await Future<void>.delayed(Duration.zero);

    expect(provider.aiAccess, isFalse);
    expect(gateway.completedPurchases, isEmpty);
    expect(provider.statusMessage, 'verification failed');
  });

  test('contains verifier exceptions and keeps entitlement denied', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway();
    final verifier = _ThrowingVerifier();
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    gateway.emit([_purchase(PurchaseProvider.aiProductId)]);
    await verifier.called.future;
    await Future<void>.delayed(Duration.zero);

    expect(provider.aiAccess, isFalse);
    expect(gateway.completedPurchases, isEmpty);
    expect(provider.statusMessage, '購入情報を確認できませんでした。通信状態を確認して、もう一度お試しください。');
  });

  test('keeps verified access and retries completion on redelivery', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _FakePurchaseGateway(completeFailures: 1);
    final verifier = _FakeVerifier(_grantedAiVerification());
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    final purchase = _purchase(PurchaseProvider.aiProductId);
    gateway.emit([purchase]);
    await gateway.firstCompletionAttempt.future;
    await Future<void>.delayed(Duration.zero);

    expect(provider.aiAccess, isTrue);
    expect(gateway.completedPurchases, isEmpty);
    expect(provider.statusMessage, '購入は確認済みですが、ストア処理を完了できませんでした。再起動後に再試行します。');

    gateway.emit([purchase]);
    await gateway.purchaseCompleted.future;

    expect(gateway.completionAttempts, 2);
    expect(gateway.completedPurchases, [purchase]);
    expect(provider.statusMessage, isNull);
  });
}

EntitlementVerification _grantedAiVerification() {
  return EntitlementVerification.granted(
    accessToken: 'verified-token',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

PurchaseDetails _purchase(String productId) {
  final purchase = PurchaseDetails(
    purchaseID: 'purchase-id',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: '0',
    status: PurchaseStatus.purchased,
  );
  purchase.pendingCompletePurchase = true;
  return purchase;
}

class _FakeVerifier implements PurchaseVerifier {
  _FakeVerifier(this.result);

  final EntitlementVerification result;
  final List<String> verifiedProductIds = [];
  final Completer<void> called = Completer<void>();

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    verifiedProductIds.add(purchase.productID);
    if (!called.isCompleted) called.complete();
    return result;
  }
}

class _ThrowingVerifier implements PurchaseVerifier {
  final Completer<void> called = Completer<void>();

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    if (!called.isCompleted) called.complete();
    throw StateError('verification unavailable');
  }
}

class _FakePurchaseGateway implements PurchaseGateway {
  _FakePurchaseGateway({
    this.available = true,
    this.productDetails = const [],
    this.notFoundIDs = const [],
    this.completeFailures = 0,
  });

  final bool available;
  final List<ProductDetails> productDetails;
  final List<String> notFoundIDs;
  int completeFailures;
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<Set<String>> queriedIds = [];
  final List<PurchaseDetails> completedPurchases = [];
  final Completer<void> firstCompletionAttempt = Completer<void>();
  final Completer<void> purchaseCompleted = Completer<void>();
  int restoreCount = 0;
  int buyCount = 0;
  int completionAttempts = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  Future<void> dispose() => _controller.close();

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
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completionAttempts += 1;
    if (!firstCompletionAttempt.isCompleted) firstCompletionAttempt.complete();
    if (completeFailures > 0) {
      completeFailures -= 1;
      throw StateError('completion unavailable');
    }
    completedPurchases.add(purchase);
    if (!purchaseCompleted.isCompleted) purchaseCompleted.complete();
  }
}
