import 'dart:async';

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:ashita_motsumono/src/services/purchase_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deduplicates concurrent AI access token refreshes', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final gateway = _TokenTestGateway();
    final verifier = _SequencedVerifier();
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    gateway.emit([_purchase()]);
    await gateway.purchaseCompleted.future;

    expect(provider.aiAccess, isTrue);
    expect(verifier.callCount, 1);

    final first = provider.getAiAccessToken();
    final second = provider.getAiAccessToken();
    await verifier.refreshStarted.future;

    expect(verifier.callCount, 2);
    verifier.refreshResult.complete(
      EntitlementVerification.granted(
        accessToken: 'fresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      ),
    );

    expect(await Future.wait([first, second]), ['fresh-token', 'fresh-token']);
    expect(verifier.callCount, 2);
  });
}

PurchaseDetails _purchase() {
  final purchase = PurchaseDetails(
    purchaseID: 'purchase-id',
    productID: PurchaseProvider.aiProductId,
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

class _SequencedVerifier implements PurchaseVerifier {
  int callCount = 0;
  final Completer<void> refreshStarted = Completer<void>();
  final Completer<EntitlementVerification> refreshResult =
      Completer<EntitlementVerification>();

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    callCount += 1;
    if (callCount == 1) {
      return EntitlementVerification.granted(
        accessToken: 'expired-token',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
    }
    if (!refreshStarted.isCompleted) refreshStarted.complete();
    return refreshResult.future;
  }
}

class _TokenTestGateway implements PurchaseGateway {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final Completer<void> purchaseCompleted = Completer<void>();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  Future<void> dispose() => _controller.close();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    return ProductDetailsResponse(
      productDetails: const [],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return true;
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (!purchaseCompleted.isCompleted) purchaseCompleted.complete();
  }
}
