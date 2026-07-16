class VerifiedEntitlementCache {
  const VerifiedEntitlementCache._();

  static String? _aiToken;
  static DateTime? _aiTokenExpiresAt;

  static String? get validAiToken {
    final token = _aiToken;
    final expiresAt = _aiTokenExpiresAt;
    if (token == null || expiresAt == null) return null;
    if (!expiresAt.isAfter(
      DateTime.now().toUtc().add(const Duration(seconds: 30)),
    )) {
      clearAiToken();
      return null;
    }
    return token;
  }

  static void setAiToken(String token, DateTime expiresAt) {
    _aiToken = token;
    _aiTokenExpiresAt = expiresAt.toUtc();
  }

  static void clearAiToken() {
    _aiToken = null;
    _aiTokenExpiresAt = null;
  }
}
