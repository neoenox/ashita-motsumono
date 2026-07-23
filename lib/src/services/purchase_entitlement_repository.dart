import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_settings.dart';
import 'purchase_verification_service.dart';
import 'verified_entitlement_cache.dart';

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.adRemoved,
    required this.aiAccess,
    this.aiPurchase,
    this.aiAccessToken,
    this.aiAccessTokenExpiresAt,
  });

  final bool adRemoved;
  final bool aiAccess;
  final PurchaseDetails? aiPurchase;
  final String? aiAccessToken;
  final DateTime? aiAccessTokenExpiresAt;

  EntitlementSnapshot copyWith({
    bool? adRemoved,
    bool? aiAccess,
    Object? aiPurchase = _unset,
    Object? aiAccessToken = _unset,
    Object? aiAccessTokenExpiresAt = _unset,
  }) {
    return EntitlementSnapshot(
      adRemoved: adRemoved ?? this.adRemoved,
      aiAccess: aiAccess ?? this.aiAccess,
      aiPurchase: identical(aiPurchase, _unset)
          ? this.aiPurchase
          : aiPurchase as PurchaseDetails?,
      aiAccessToken: identical(aiAccessToken, _unset)
          ? this.aiAccessToken
          : aiAccessToken as String?,
      aiAccessTokenExpiresAt: identical(aiAccessTokenExpiresAt, _unset)
          ? this.aiAccessTokenExpiresAt
          : aiAccessTokenExpiresAt as DateTime?,
    );
  }
}

class PurchaseEntitlementRepository {
  PurchaseEntitlementRepository(
    this._settings, {
    required this.removeAdsProductId,
    required this.aiAccessProductId,
  }) : _snapshot = EntitlementSnapshot(
         adRemoved: _settings.adRemoved,
         aiAccess: _settings.aiAccess,
       );

  final AppSettings _settings;
  final String removeAdsProductId;
  final String aiAccessProductId;
  EntitlementSnapshot _snapshot;

  EntitlementSnapshot get snapshot => _snapshot;

  Future<EntitlementSnapshot> grant(
    PurchaseDetails purchase,
    EntitlementVerification verification,
  ) async {
    if (purchase.productID == removeAdsProductId) {
      await _settings.setAdRemoved(true);
      _snapshot = _snapshot.copyWith(adRemoved: true);
      return _snapshot;
    }
    if (purchase.productID != aiAccessProductId) {
      throw UnsupportedError('Unsupported purchase product: ${purchase.productID}');
    }

    final token = verification.accessToken;
    final expiresAt = verification.expiresAt;
    if (token == null || expiresAt == null) {
      throw StateError('AI entitlement verification did not include a token.');
    }

    await _settings.setAiAccess(true);
    VerifiedEntitlementCache.setAiToken(token, expiresAt);
    _snapshot = _snapshot.copyWith(
      aiAccess: true,
      aiPurchase: purchase,
      aiAccessToken: token,
      aiAccessTokenExpiresAt: expiresAt.toUtc(),
    );
    return _snapshot;
  }

  Future<EntitlementSnapshot> deny(String productId) async {
    if (productId == removeAdsProductId) {
      await _settings.setAdRemoved(false);
      _snapshot = _snapshot.copyWith(adRemoved: false);
      return _snapshot;
    }
    if (productId != aiAccessProductId) {
      throw UnsupportedError('Unsupported purchase product: $productId');
    }

    await _settings.setAiAccess(false);
    VerifiedEntitlementCache.clearAiToken();
    _snapshot = _snapshot.copyWith(
      aiAccess: false,
      aiPurchase: null,
      aiAccessToken: null,
      aiAccessTokenExpiresAt: null,
    );
    return _snapshot;
  }

  String? validAiAccessToken(DateTime now) {
    final token = _snapshot.aiAccessToken;
    final expiry = _snapshot.aiAccessTokenExpiresAt;
    if (!_snapshot.aiAccess || token == null || expiry == null) return null;
    return expiry.isAfter(now.toUtc().add(const Duration(seconds: 30)))
        ? token
        : null;
  }
}

const _unset = Object();
