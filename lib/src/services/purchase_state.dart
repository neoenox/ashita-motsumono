import 'package:in_app_purchase/in_app_purchase.dart';

enum PurchasePhase {
  initializing,
  restoring,
  ready,
  purchasing,
  unavailable,
  failed,
}

enum PurchaseOperationPhase {
  idle,
  launching,
  pending,
  verifying,
  completing,
  succeeded,
  canceled,
  retryable,
  denied,
  failed,
}

class PurchaseOperationState {
  const PurchaseOperationState({
    required this.phase,
    required this.generation,
    this.statusMessage,
  });

  const PurchaseOperationState.idle()
    : phase = PurchaseOperationPhase.idle,
      generation = 0,
      statusMessage = null;

  final PurchaseOperationPhase phase;
  final int generation;
  final String? statusMessage;

  bool get busy => switch (phase) {
    PurchaseOperationPhase.launching ||
    PurchaseOperationPhase.pending ||
    PurchaseOperationPhase.verifying ||
    PurchaseOperationPhase.completing => true,
    _ => false,
  };

  PurchaseOperationState copyWith({
    PurchaseOperationPhase? phase,
    int? generation,
    Object? statusMessage = _unset,
  }) {
    return PurchaseOperationState(
      phase: phase ?? this.phase,
      generation: generation ?? this.generation,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
    );
  }
}

class PurchaseState {
  PurchaseState({
    required this.phase,
    required this.adRemoved,
    required this.aiAccess,
    this.storeAvailable = false,
    this.adsProduct,
    this.aiProduct,
    this.statusMessage,
    Map<String, PurchaseOperationState> operations = const {},
  }) : operations = Map.unmodifiable(operations);

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
  final Map<String, PurchaseOperationState> operations;

  bool get busy => switch (phase) {
    PurchasePhase.initializing ||
    PurchasePhase.restoring ||
    PurchasePhase.purchasing => true,
    _ => operations.values.any((operation) => operation.busy),
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
      phase == PurchasePhase.ready &&
      storeAvailable &&
      adsProduct != null &&
      !operationFor(adsProduct!.id).busy;

  bool get canPurchaseAi =>
      phase == PurchasePhase.ready &&
      storeAvailable &&
      aiProduct != null &&
      !operationFor(aiProduct!.id).busy;

  String get priceLabel =>
      adsProduct == null ? '価格は購入前に表示' : '買い切り ${adsProduct!.price}';

  String get aiPriceLabel =>
      aiProduct == null ? '価格は購入前に表示' : '買い切り ${aiProduct!.price}';

  PurchaseOperationState operationFor(String productId) =>
      operations[productId] ?? const PurchaseOperationState.idle();

  bool canTransitionTo(PurchasePhase next) {
    if (phase == next) return true;
    return switch (phase) {
      PurchasePhase.initializing =>
        next == PurchasePhase.restoring ||
            next == PurchasePhase.unavailable ||
            next == PurchasePhase.failed,
      PurchasePhase.restoring =>
        next == PurchasePhase.ready ||
            next == PurchasePhase.unavailable ||
            next == PurchasePhase.failed,
      PurchasePhase.ready =>
        next == PurchasePhase.restoring ||
            next == PurchasePhase.purchasing ||
            next == PurchasePhase.unavailable ||
            next == PurchasePhase.failed,
      PurchasePhase.purchasing =>
        next == PurchasePhase.ready ||
            next == PurchasePhase.unavailable ||
            next == PurchasePhase.failed,
      PurchasePhase.unavailable =>
        next == PurchasePhase.restoring ||
            next == PurchasePhase.ready ||
            next == PurchasePhase.failed,
      PurchasePhase.failed =>
        next == PurchasePhase.restoring ||
            next == PurchasePhase.ready ||
            next == PurchasePhase.unavailable,
    };
  }

  PurchaseState transitionTo(
    PurchasePhase next, {
    Object? statusMessage = _unset,
  }) {
    if (!canTransitionTo(next)) {
      throw StateError('Invalid purchase transition: $phase -> $next');
    }
    return copyWith(phase: next, statusMessage: statusMessage);
  }

  PurchaseState withOperation(
    String productId,
    PurchaseOperationState operation, {
    Object? statusMessage = _unset,
  }) {
    return copyWith(
      operations: {...operations, productId: operation},
      statusMessage: statusMessage,
    );
  }

  PurchaseState copyWith({
    PurchasePhase? phase,
    bool? adRemoved,
    bool? aiAccess,
    bool? storeAvailable,
    Object? adsProduct = _unset,
    Object? aiProduct = _unset,
    Object? statusMessage = _unset,
    Map<String, PurchaseOperationState>? operations,
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
      operations: operations ?? this.operations,
    );
  }
}

const _unset = Object();
