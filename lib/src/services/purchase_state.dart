import 'package:in_app_purchase/in_app_purchase.dart';

enum PurchasePhase {
  initializing,
  restoring,
  ready,
  purchasing,
  unavailable,
  failed,
}

class PurchaseState {
  const PurchaseState({
    required this.phase,
    required this.adRemoved,
    required this.aiAccess,
    this.storeAvailable = false,
    this.adsProduct,
    this.aiProduct,
    this.statusMessage,
  });

  factory PurchaseState.initial({
    required bool adRemoved,
    required bool aiAccess,
  }) => PurchaseState(
    phase: PurchasePhase.initializing,
    adRemoved: adRemoved,
    aiAccess: aiAccess,
  );

  final PurchasePhase phase;
  final bool adRemoved;
  final bool aiAccess;
  final bool storeAvailable;
  final ProductDetails? adsProduct;
  final ProductDetails? aiProduct;
  final String? statusMessage;

  bool get busy => switch (phase) {
    PurchasePhase.initializing ||
    PurchasePhase.restoring ||
    PurchasePhase.purchasing => true,
    _ => false,
  };

  bool get restoring => switch (phase) {
    PurchasePhase.initializing || PurchasePhase.restoring => true,
    _ => false,
  };

  bool get entitlementResolved => switch (phase) {
    PurchasePhase.initializing || PurchasePhase.restoring => false,
    _ => true,
  };

  bool get canPurchase =>
      phase == PurchasePhase.ready && storeAvailable && adsProduct != null;

  bool get canPurchaseAi =>
      phase == PurchasePhase.ready && storeAvailable && aiProduct != null;

  String get priceLabel =>
      adsProduct == null ? '価格は購入前に表示' : '買い切り ${adsProduct!.price}';

  String get aiPriceLabel =>
      aiProduct == null ? '価格は購入前に表示' : '買い切り ${aiProduct!.price}';

  PurchaseState copyWith({
    PurchasePhase? phase,
    bool? adRemoved,
    bool? aiAccess,
    bool? storeAvailable,
    Object? adsProduct = _unset,
    Object? aiProduct = _unset,
    Object? statusMessage = _unset,
  }) {
    return PurchaseState(
      phase: phase ?? this.phase,
      adRemoved: adRemoved ?? this.adRemoved,
      aiAccess: aiAccess ?? this.aiAccess,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      adsProduct: identical(adsProduct, _unset)
          ? this.adsProduct
          : adsProduct as ProductDetails?,
      aiProduct: identical(aiProduct, _unset)
          ? this.aiProduct
          : aiProduct as ProductDetails?,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
    );
  }
}

const _unset = Object();
