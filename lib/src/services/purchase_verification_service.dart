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
  }) : this._(verified: true, accessToken: accessToken, expiresAt: expiresAt);

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

/// 購入証明を検証し、共有状態を変更せず結果だけを返す。
abstract interface class PurchaseVerifier {
  Future<EntitlementVerification> verify(PurchaseDetails purchase);
}

/// Providerのライフサイクル終了後に返った検証結果を適用対象外にする。
class PurchaseVerifierGuard implements PurchaseVerifier {
  PurchaseVerifierGuard(this._delegate);

  final PurchaseVerifier _delegate;
  bool _closed = false;

  void close() {
    _closed = true;
  }

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    if (_closed) return _closedResult;
    final result = await _delegate.verify(purchase);
    return _closed ? _closedResult : result;
  }

  static const _closedResult = EntitlementVerification.retryable(
    '購入確認処理は終了されています。',
  );
}

class PurchaseVerificationService implements PurchaseVerifier {
  PurchaseVerificationService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? _configuredBaseUrl,
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _configuredBaseUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
    defaultValue: '',
  );
  static const _aiProductId = String.fromEnvironment(
    'IAP_AI_ACCESS_PRODUCT_ID',
    defaultValue: 'ai_analysis',
  );

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }

  @override
  Future<EntitlementVerification> verify(PurchaseDetails purchase) async {
    if (_closed) {
      return const EntitlementVerification.retryable('購入確認サービスは終了されています。');
    }
    final endpoint = _endpoint('/entitlements/verify');
    if (endpoint == null) {
      return const EntitlementVerification.retryable('購入確認サーバーが設定されていません。');
    }
    final verificationData = purchase.verificationData.serverVerificationData
        .trim();
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
      if (_closed) {
        return const EntitlementVerification.retryable('購入確認サービスは終了されています。');
      }
      final payload = _decodeObject(response.body);
      if (response.statusCode == 200 && payload['verified'] == true) {
        final token = payload['accessToken'] as String?;
        final expiresAt = DateTime.tryParse(
          payload['expiresAt'] as String? ?? '',
        );
        if (purchase.productID == _aiProductId &&
            (token == null || expiresAt == null)) {
          return const EntitlementVerification.denied(
            'AI利用権トークンを確認できませんでした。',
          );
        }
        return EntitlementVerification.granted(
          accessToken: token,
          expiresAt: expiresAt,
        );
      }
      final message = payload['error'] as String? ?? '購入を確認できませんでした。';
      return response.statusCode >= 500 || response.statusCode == 429
          ? EntitlementVerification.retryable(message)
          : EntitlementVerification.denied(message);
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
