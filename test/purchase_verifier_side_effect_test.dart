import 'dart:async';
import 'dart:convert';

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/purchase_entitlement_repository.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:ashita_motsumono/src/services/purchase_verification_service.dart';
import 'package:ashita_motsumono/src/services/verified_entitlement_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VerifiedEntitlementCache.clearAiTokenRefresher();
    VerifiedEntitlementCache.clearAiToken();
  });

  tearDown(() {
    VerifiedEntitlementCache.clearAiTokenRefresher();
    VerifiedEntitlementCache.clearAiToken();
  });

  test(
    'verification success does not mutate the shared AI token cache',
    () async {
      VerifiedEntitlementCache.setAiToken(
        'existing-token',
        DateTime.now().toUtc().add(const Duration(minutes: 10)),
      );
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 20));
      final service = PurchaseVerificationService(
        baseUrl: 'https://example.com',
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'verified': true,
              'accessToken': 'new-token',
              'expiresAt': expiresAt.toIso8601String(),
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);

      final result = await service.verify(_purchase());

      expect(result.verified, isTrue);
      expect(result.accessToken, 'new-token');
      expect(VerifiedEntitlementCache.validAiToken, 'existing-token');
    },
  );

  test(
    'verification denial does not clear the shared AI token cache',
    () async {
      VerifiedEntitlementCache.setAiToken(
        'existing-token',
        DateTime.now().toUtc().add(const Duration(minutes: 10)),
      );
      final service = PurchaseVerificationService(
        baseUrl: 'https://example.com',
        client: MockClient((_) async {
          return http.Response(jsonEncode({'error': 'purchase revoked'}), 403);
        }),
      );
      addTearDown(service.close);

      final result = await service.verify(_purchase());

      expect(result.verified, isFalse);
      expect(result.retryable, isFalse);
      expect(result.message, 'purchase revoked');
      expect(VerifiedEntitlementCache.validAiToken, 'existing-token');
    },
  );

  test(
    'repository publishes the AI token only after persistence succeeds',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final settings = _GateAppSettings(preferences);
      final repository = PurchaseEntitlementRepository(
        settings,
        removeAdsProductId: PurchaseProvider.productId,
        aiAccessProductId: PurchaseProvider.aiProductId,
      );

      final grant = repository.grant(_purchase(), _granted());
      await settings.writeStarted.future;

      expect(repository.snapshot.aiAccess, isFalse);
      expect(VerifiedEntitlementCache.validAiToken, isNull);

      settings.allowWrite.complete();
      await grant;

      expect(repository.snapshot.aiAccess, isTrue);
      expect(settings.aiAccess, isTrue);
      expect(VerifiedEntitlementCache.validAiToken, 'verified-token');
    },
  );

  test(
    'repository persistence failure leaves state and cache unchanged',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final settings = _FailingAppSettings(preferences);
      final repository = PurchaseEntitlementRepository(
        settings,
        removeAdsProductId: PurchaseProvider.productId,
        aiAccessProductId: PurchaseProvider.aiProductId,
      );

      await expectLater(
        repository.grant(_purchase(), _granted()),
        throwsStateError,
      );

      expect(repository.snapshot.aiAccess, isFalse);
      expect(settings.aiAccess, isFalse);
      expect(VerifiedEntitlementCache.validAiToken, isNull);
    },
  );

  test(
    'disposing the provider discards an in-flight verification result',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final settings = AppSettings(preferences);
      final gateway = _FakePurchaseGateway();
      final verifier = _DeferredVerifier();
      final provider = AppPurchaseProvider(
        settings,
        gateway: gateway,
        verifier: verifier,
      );
      addTearDown(gateway.dispose);
      await provider.ready;

      gateway.emit([_purchase()]);
      await verifier.called.future;

      provider.dispose();
      verifier.result.complete(_granted());
      await verifier.returned.future;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(settings.aiAccess, isFalse);
      expect(VerifiedEntitlementCache.validAiToken, isNull);
      expect(gateway.completionAttempts, 0);
    },
  );

  test(
    'closing verification during a request returns no applicable result',
    () async {
      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      final service = PurchaseVerificationService(
        baseUrl: 'https://example.com',
        client: MockClient((_) async {
          requestStarted.complete();
          return response.future;
        }),
      );

      final verification = service.verify(_purchase());
      await requestStarted.future;
      service.close();
      response.complete(
        http.Response(
          jsonEncode({
            'verified': true,
            'accessToken': 'late-token',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          }),
          200,
        ),
      );

      final result = await verification;

      expect(result.verified, isFalse);
      expect(result.retryable, isTrue);
      expect(VerifiedEntitlementCache.validAiToken, isNull);
    },
  );
}

EntitlementVerification _granted() {
  return EntitlementVerification.granted(
    accessToken: 'verified-token',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  );
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

class _GateAppSettings extends AppSettings {
  _GateAppSettings(SharedPreferences preferences) : super(preferences);

  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();

  @override
  Future<void> setAiAccess(bool enabled) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await allowWrite.future;
    await super.setAiAccess(enabled);
  }
}

class _FailingAppSettings extends AppSettings {
  _FailingAppSettings(SharedPreferences preferences) : super(preferences);

  @override
  Future<void> setAiAccess(bool enabled) async {
    throw StateError('simulated persistence failure');
  }
}

class _DeferredVerifier implements PurchaseVerifier {
  final Completer<void> called = Completer<void>();
  final Completer<void> returned = Completer<void>();
  final Completer<EntitlementVerification> result =
      Completer<EntitlementVerification>();

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    if (!called.isCompleted) called.complete();
    final verification = await result.future;
    if (!returned.isCompleted) returned.complete();
    return verification;
  }
}

class _FakePurchaseGateway implements PurchaseGateway {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
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
  }
}
