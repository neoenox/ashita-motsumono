class VerifiedEntitlementCache {
  const VerifiedEntitlementCache._();

  static String? _aiToken;
  static DateTime? _aiTokenExpiresAt;
  static Future<String?> Function()? _aiTokenRefresher;
  static Future<String?>? _refreshInFlight;

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

  static Future<String?> getAiToken() async {
    final current = validAiToken;
    if (current != null) return current;
    final refresher = _aiTokenRefresher;
    if (refresher == null) return null;
    final pending = _refreshInFlight ??= refresher();
    try {
      return await pending;
    } finally {
      if (identical(_refreshInFlight, pending)) _refreshInFlight = null;
    }
  }

  static void registerAiTokenRefresher(Future<String?> Function() refresher) {
    _aiTokenRefresher = refresher;
  }

  static void clearAiTokenRefresher() {
    _aiTokenRefresher = null;
    _refreshInFlight = null;
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
