import 'dart:async';

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:ashita_motsumono/src/services/purchase_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('keeps existing AI entitlement on retryable verification failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    final gateway = _FakePurchaseGateway();
    final verifier = _MutableVerifier(
      EntitlementVerification.granted(
        accessToken: 'verified-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      ),
    );
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    final purchase = _purchase();
    gateway.emit([purchase]);
    await gateway.purchaseCompleted.future;

    expect(provider.aiAccess, isTrue);
    expect(preferences.getBool('aiAccess'), isTrue);

    verifier.result = const EntitlementVerification.retryable(
      'verification temporarily unavailable',
    );
    gateway.emit([purchase]);
    await verifier.waitForCalls(2);
    await Future<void>.delayed(Duration.zero);

    expect(provider.aiAccess, isTrue);
    expect(preferences.getBool('aiAccess'), isTrue);
    expect(provider.statusMessage, 'verification temporarily unavailable');
    expect(gateway.completionAttempts, 1);
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

class _MutableVerifier implements PurchaseVerifier {
  _MutableVerifier(this.result);

  EntitlementVerification result;
  int callCount = 0;
  final List<_CallWaiter> _waiters = [];

  Future<void> waitForCalls(int expected) {
    if (callCount >= expected) return Future<void>.value();
    final completer = Completer<void>();
    _waiters.add(_CallWaiter(expected, completer));
    return completer.future;
  }

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    callCount += 1;
    for (final waiter in List<_CallWaiter>.from(_waiters)) {
      if (callCount >= waiter.expected && !waiter.completer.isCompleted) {
        waiter.completer.complete();
        _waiters.remove(waiter);
      }
    }
    return result;
  }
}

class _CallWaiter {
  const _CallWaiter(this.expected, this.completer);

  final int expected;
  final Completer<void> completer;
}

class _FakePurchaseGateway implements PurchaseGateway {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final Completer<void> purchaseCompleted = Completer<void>();
  int completionAttempts = 0;

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
    completionAttempts += 1;
    if (!purchaseCompleted.isCompleted) purchaseCompleted.complete();
  }
}
