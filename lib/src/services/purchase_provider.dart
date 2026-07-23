import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'purchase_coordinator.dart';
import 'purchase_gateway.dart';
import 'purchase_state.dart';
import 'purchase_verification_service.dart';

export 'purchase_gateway.dart' show InAppPurchaseGateway, PurchaseGateway;

abstract class PurchaseProvider extends ChangeNotifier {
  bool get adRemoved;
  bool get aiAccess;
  bool get busy;
  bool get restoring => false;
  bool get entitlementResolved => true;
  PurchaseState? get state => null;
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

  Future<String?> getAiAccessToken() async => null;
}

class AppPurchaseProvider extends PurchaseProvider {
  AppPurchaseProvider(
    AppSettings settings, {
    PurchaseGateway? gateway,
    PurchaseVerifier? verifier,
  }) {
    _coordinator = PurchaseCoordinator(
      settings: settings,
      gateway: gateway ?? InAppPurchaseGateway(),
      verifier: verifier ?? PurchaseVerificationService(),
      ownsVerifier: verifier == null,
      removeAdsProductId: PurchaseProvider.productId,
      aiAccessProductId: PurchaseProvider.aiProductId,
    );
    _coordinator.addListener(notifyListeners);
  }

  late final PurchaseCoordinator _coordinator;

  @override
  Future<void> get ready => _coordinator.ready;

  @override
  PurchaseState get state => _coordinator.state;

  @override
  bool get adRemoved => state.adRemoved;

  @override
  bool get aiAccess => state.aiAccess;

  @override
  bool get busy => state.busy;

  @override
  bool get restoring => state.restoring;

  @override
  bool get entitlementResolved => state.entitlementResolved;

  @override
  bool get canPurchase => state.canPurchase;

  @override
  bool get canPurchaseAi => state.canPurchaseAi;

  @override
  String? get statusMessage => state.statusMessage;

  @override
  String get priceLabel => state.priceLabel;

  @override
  String get aiPriceLabel => state.aiPriceLabel;

  @override
  Future<void> purchase() => _coordinator.purchase(PurchaseProvider.productId);

  @override
  Future<void> purchaseAi() =>
      _coordinator.purchase(PurchaseProvider.aiProductId);

  @override
  Future<void> restore() => _coordinator.restore();

  @override
  Future<String?> getAiAccessToken() => _coordinator.getAiAccessToken();

  @override
  void dispose() {
    _coordinator.removeListener(notifyListeners);
    _coordinator.dispose();
    super.dispose();
  }
}
