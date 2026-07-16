import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

class EntitlementVerification {
  const EntitlementVerification._({
    required this.verified,
    this.accessToken,
    this.expiresAt,
    this.message,
    this.retryable = false,
  });

  const EntitlementVerification.granted({
    String? accessToken,
    DateTime? expiresAt,
  }) : this._(
          verified: true,
          accessToken: accessToken,
          expiresAt: expiresAt,
        );

  const EntitlementVerification.denied(String message)
      : this._(verified: false, message: message);

  const EntitlementVerification.retryable(String message)
      : this._(verified: false, message: message, retryable: true);

  final bool verified;
  final String? accessToken;
  final DateTime? expiresAt;
  final String? message;
  final bool retryable;
}

abstract interface class PurchaseVerifier {
  Future<EntitlementVerification> verify(PurchaseDetails purchase);
}

class PurchaseVerificationService implements PurchaseVerifier {
  PurchaseVerificationService({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? _configuredBaseUrl,
        _client = client ?? http.Client();

  static const _configuredBaseUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
    defaultValue: '',
  );

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    final endpoint = _endpoint('/entitlements/verify');
    if (endpoint == null) {
      return const EntitlementVerification.retryable(
        '購入確認サーバーが設定されていません。',
      );
    }
    final verificationData =
        purchase.verificationData.serverVerificationData.trim();
    if (verificationData.isEmpty) {
      return const EntitlementVerification.denied('購入証明データがありません。');
    }

    try {
      final response = await _client
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'platform': Platform.isAndroid ? 'android' : 'ios',
              'productId': purchase.productID,
              'verificationData': verificationData,
              'source': purchase.verificationData.source,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final payload = _decodeObject(response.body);
      if (response.statusCode == 200 && payload['verified'] == true) {
        return EntitlementVerification.granted(
          accessToken: payload['accessToken'] as String?,
          expiresAt: DateTime.tryParse(payload['expiresAt'] as String? ?? ''),
        );
      }
      final message = payload['error'] as String? ?? '購入を確認できませんでした。';
      if (response.statusCode >= 500 || response.statusCode == 429) {
        return EntitlementVerification.retryable(message);
      }
      return EntitlementVerification.denied(message);
    } on SocketException {
      return const EntitlementVerification.retryable('購入確認サーバーに接続できません。');
    } on TimeoutException {
      return const EntitlementVerification.retryable('購入確認がタイムアウトしました。');
    } on FormatException {
      return const EntitlementVerification.retryable('購入確認サーバーの応答が不正です。');
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Purchase verification failed: $error');
      return const EntitlementVerification.retryable('購入情報の確認に失敗しました。');
    }
  }

  Uri? _endpoint(String path) {
    final raw = _baseUrl.trim();
    if (raw.isEmpty) return null;
    final base = Uri.tryParse(raw);
    if (base == null || !base.hasAuthority) return null;
    final local = base.host == 'localhost' || base.host == '127.0.0.1';
    if (base.scheme != 'https' && !(kDebugMode && local)) return null;
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$basePath$path');
  }

  static Map<String, dynamic> _decodeObject(String body) {
    final value = jsonDecode(body);
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  }
}
