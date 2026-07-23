import 'dart:async';

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:ashita_motsumono/src/services/purchase_state.dart';
import 'package:ashita_motsumono/src/services/purchase_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('keeps cached entitlement visible while restore is pending', () async {
    SharedPreferences.setMockInitialValues({
      'purchase_ad_removed': true,
      'purchase_ai_access': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    final gateway = _FakePurchaseGateway(blockRestore: true);
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: _MutableVerifier(_granted()),
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);

    await gateway.restoreInvoked.future;

    expect(provider.adRemoved, isTrue);
    expect(provider.aiAccess, isTrue);
    expect(provider.restoring, isTrue);
    expect(provider.entitlementResolved, isFalse);
    expect(provider.state.phase, PurchasePhase.restoring);
    expect(provider.canPurchase, isFalse);
    expect(provider.canPurchaseAi, isFalse);

    gateway.completeRestore();
    await provider.ready;

    expect(provider.state.phase, PurchasePhase.ready);
    expect(provider.entitlementResolved, isTrue);
  });

  test('ready waits for purchase updates queued during restore', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    final gateway = _FakePurchaseGateway(blockRestore: true);
    final verifier = _QueuedVerifier();
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);

    await gateway.restoreInvoked.future;
    gateway.emit([_purchase()]);
    gateway.completeRestore();
    await verifier.waitForCalls(1);

    var readyCompleted = false;
    unawaited(provider.ready.then((_) => readyCompleted = true));
    await Future<void>.delayed(Duration.zero);

    expect(readyCompleted, isFalse);
    expect(provider.state.phase, PurchasePhase.restoring);

    verifier.completeCall(0, _granted());
    await provider.ready;

    expect(provider.aiAccess, isTrue);
    expect(provider.state.phase, PurchasePhase.ready);
  });

  test('serializes purchase verification events', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    final gateway = _FakePurchaseGateway();
    final verifier = _QueuedVerifier();
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    gateway.emit([_purchase(purchaseId: 'first')]);
    await verifier.waitForCalls(1);
    gateway.emit([_purchase(purchaseId: 'second')]);
    await Future<void>.delayed(Duration.zero);

    expect(verifier.callCount, 1);

    verifier.completeCall(
      0,
      const EntitlementVerification.denied('first purchase denied'),
    );
    await verifier.waitForCalls(2);
    verifier.completeCall(1, _granted());
    await gateway.waitForCompletionAttempts(1);
    await Future<void>.delayed(Duration.zero);

    expect(provider.aiAccess, isTrue);
    expect(settings.aiAccess, isTrue);
    expect(verifier.callCount, 2);
  });

  test('keeps existing AI entitlement on retryable verification failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    final gateway = _FakePurchaseGateway();
    final verifier = _MutableVerifier(_granted());
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
    expect(settings.aiAccess, isTrue);

    verifier.result = const EntitlementVerification.retryable(
      'verification temporarily unavailable',
    );
    gateway.emit([purchase]);
    await verifier.waitForCalls(2);
    await Future<void>.delayed(Duration.zero);

    expect(provider.aiAccess, isTrue);
    expect(settings.aiAccess, isTrue);
    expect(provider.statusMessage, 'verification temporarily unavailable');
    expect(gateway.completionAttempts, 1);
    expect(
      provider.state.operationFor(PurchaseProvider.aiProductId).phase,
      PurchaseOperationPhase.retryable,
    );
  });

  test('revokes entitlement only after explicit verification denial', () async {
    SharedPreferences.setMockInitialValues({'purchase_ai_access': true});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    final gateway = _FakePurchaseGateway();
    final verifier = _MutableVerifier(
      const EntitlementVerification.denied('purchase was revoked'),
    );
    final provider = AppPurchaseProvider(
      settings,
      gateway: gateway,
      verifier: verifier,
    );
    addTearDown(provider.dispose);
    addTearDown(gateway.dispose);
    await provider.ready;

    gateway.emit([_purchase()]);
    await verifier.waitForCalls(1);
    await Future<void>.delayed(Duration.zero);

    expect(provider.aiAccess, isFalse);
    expect(settings.aiAccess, isFalse);
    expect(provider.statusMessage, 'purchase was revoked');
    expect(
      provider.state.operationFor(PurchaseProvider.aiProductId).phase,
      PurchaseOperationPhase.denied,
    );
  });

  test('rejects invalid global state transitions', () {
    final state = PurchaseState.initial(adRemoved: false, aiAccess: false);

    expect(
      () => state.transitionTo(PurchasePhase.purchasing),
      throwsStateError,
    );
  });
}

EntitlementVerification _granted() {
  return EntitlementVerification.granted(
    accessToken: 'verified-token',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  );
}

PurchaseDetails _purchase({String purchaseId = 'purchase-id'}) {
  final purchase = PurchaseDetails(
    purchaseID: purchaseId,
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
    _recordCall();
    return result;
  }

  void _recordCall() {
    callCount += 1;
    for (final waiter in List<_CallWaiter>.from(_waiters)) {
      if (callCount >= waiter.expected && !waiter.completer.isCompleted) {
        waiter.completer.complete();
        _waiters.remove(waiter);
      }
    }
  }
}

class _QueuedVerifier implements PurchaseVerifier {
  int callCount = 0;
  final List<Completer<EntitlementVerification>> _calls = [];
  final List<_CallWaiter> _waiters = [];

  Future<void> waitForCalls(int expected) {
    if (callCount >= expected) return Future<void>.value();
    final completer = Completer<void>();
    _waiters.add(_CallWaiter(expected, completer));
    return completer.future;
  }

  void completeCall(int index, EntitlementVerification result) {
    _calls[index].complete(result);
  }

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) {
    callCount += 1;
    final completer = Completer<EntitlementVerification>();
    _calls.add(completer);
    for (final waiter in List<_CallWaiter>.from(_waiters)) {
      if (callCount >= waiter.expected && !waiter.completer.isCompleted) {
        waiter.completer.complete();
        _waiters.remove(waiter);
      }
    }
    return completer.future;
  }
}

class _CallWaiter {
  const _CallWaiter(this.expected, this.completer);

  final int expected;
  final Completer<void> completer;
}

class _FakePurchaseGateway implements PurchaseGateway {
  _FakePurchaseGateway({this.blockRestore = false});

  final bool blockRestore;
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final Completer<void> purchaseCompleted = Completer<void>();
  final Completer<void> restoreInvoked = Completer<void>();
  final Completer<void> _restoreGate = Completer<void>();
  final List<_CallWaiter> _completionWaiters = [];
  int completionAttempts = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  void completeRestore() {
    if (!_restoreGate.isCompleted) _restoreGate.complete();
  }

  Future<void> waitForCompletionAttempts(int expected) {
    if (completionAttempts >= expected) return Future<void>.value();
    final completer = Completer<void>();
    _completionWaiters.add(_CallWaiter(expected, completer));
    return completer.future;
  }

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
  Future<void> restorePurchases() async {
    if (!restoreInvoked.isCompleted) restoreInvoked.complete();
    if (blockRestore) await _restoreGate.future;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completionAttempts += 1;
    if (!purchaseCompleted.isCompleted) purchaseCompleted.complete();
    for (final waiter in List<_CallWaiter>.from(_completionWaiters)) {
      if (completionAttempts >= waiter.expected &&
          !waiter.completer.isCompleted) {
        waiter.completer.complete();
        _completionWaiters.remove(waiter);
      }
    }
  }
}
