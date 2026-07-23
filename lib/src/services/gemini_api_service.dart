import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;

import '../models/entities.dart';
import 'image_file_service.dart';

class _GeminiDraft {
  _GeminiDraft({
    required this.title,
    required this.category,
    this.dueDate,
    this.amount,
    required this.items,
    this.note,
  });

  factory _GeminiDraft.fromJson(Map<String, dynamic> json) => _GeminiDraft(
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? 'other',
    dueDate: json['dueDate'] as String?,
    amount: (json['amount'] as num?)?.toInt(),
    items:
        (json['items'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .toList() ??
        const [],
    note: json['note'] as String?,
  );

  final String title;
  final String category;
  final String? dueDate;
  final int? amount;
  final List<String> items;
  final String? note;

  ExtractionDraft toDraft() => ExtractionDraft(
    title: title.trim(),
    category: switch (category) {
      'payment' => TodoCategory.payment,
      'submit' => TodoCategory.submit,
      'event' => TodoCategory.event,
      'item' => TodoCategory.item,
      _ => TodoCategory.other,
    },
    dueDate: dueDate?.length == 10 ? DateTime.tryParse(dueDate!) : null,
    amount: amount,
    items: items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(),
    note: note?.trim(),
  );
}

sealed class GeminiResult {}

class GeminiSuccess extends GeminiResult {
  GeminiSuccess({required this.drafts});
  final List<ExtractionDraft> drafts;
}

class GeminiEmpty extends GeminiResult {}

class GeminiError extends GeminiResult {
  GeminiError(this.message);
  final String message;
}

class GeminiApiService {
  GeminiApiService({this.proxyUrl, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  String? proxyUrl;
  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  static const _defaultProxyUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
    defaultValue: '',
  );

  factory GeminiApiService.defaultInstance() =>
      GeminiApiService(proxyUrl: _defaultProxyUrl);

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }

  Future<GeminiResult> analyzeImage(
    File imageFile, {
    required String accessToken,
  }) async {
    if (_closed) return GeminiError('AI解析サービスは終了されています');
    final endpoint = _endpoint('/analyze');
    if (endpoint == null) return GeminiError('AI解析サーバーが設定されていません');
    if (accessToken.trim().isEmpty) return GeminiError('AI分析の購入確認が必要です');
    if (!await imageFile.exists()) return GeminiError('画像ファイルが見つかりません');

    final size = await imageFile.length();
    if (size == 0) return GeminiError('画像ファイルが空です');
    if (size > ImageFileService.maxImageBytes) {
      return GeminiError('画像サイズが大きすぎます。別の画像を選択してください');
    }
    final mimeType = _detectMimeType(imageFile.path);
    if (mimeType == null) return GeminiError('対応していない画像形式です');

    try {
      final bytes = await imageFile.readAsBytes();
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      String timezone;
      try {
        timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
      } on Object {
        timezone = 'Asia/Tokyo';
      }

      final response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${accessToken.trim()}',
            },
            body: jsonEncode({
              'imageBase64': base64Encode(bytes),
              'mimeType': mimeType,
              'today': today,
              'timezone': timezone,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return GeminiError('AI分析の購入確認期限が切れました。購入情報を復元してください');
      }
      if (response.statusCode == 413) return GeminiError('画像サイズが大きすぎます');
      if (response.statusCode == 429) return GeminiError('AI解析の利用回数が上限に達しました');
      if (response.statusCode != 200) {
        return GeminiError('AI解析サーバーでエラーが発生しました');
      }
      return _parseResponse(response.body);
    } on SocketException {
      return GeminiError('ネットワークに接続できません');
    } on http.ClientException {
      return GeminiError('サーバーに接続できません');
    } on TimeoutException {
      return GeminiError('通信がタイムアウトしました。接続状況を確認してください');
    } on FormatException {
      return GeminiError('応答の解析に失敗しました');
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Gemini request failed: $error');
      return GeminiError('AI解析で予期しないエラーが発生しました');
    }
  }

  Uri? _endpoint(String path) {
    final raw = (proxyUrl ?? _defaultProxyUrl).trim();
    if (raw.isEmpty) return null;
    final base = Uri.tryParse(raw);
    if (base == null || !base.hasAuthority) return null;
    final local = base.host == 'localhost' || base.host == '127.0.0.1';
    if (base.scheme != 'https' && !(kDebugMode && local)) return null;
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$basePath$path');
  }

  GeminiResult _parseResponse(String body) {
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) return GeminiEmpty();
    if (root['error'] != null) return GeminiError('AI解析サーバーでエラーが発生しました');
    final candidates = root['candidates'];
    if (candidates is! List || candidates.isEmpty) return GeminiEmpty();
    final first = candidates.first;
    if (first is! Map<String, dynamic>) return GeminiEmpty();
    final content = first['content'];
    if (content is! Map<String, dynamic>) return GeminiEmpty();
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return GeminiEmpty();
    final part = parts.first;
    if (part is! Map<String, dynamic>) return GeminiEmpty();
    final text = part['text'];
    if (text is! String || text.trim().isEmpty) return GeminiEmpty();
    final parsed = jsonDecode(text);
    if (parsed is! Map<String, dynamic>) return GeminiEmpty();
    final values = parsed['drafts'];
    if (values is! List) return GeminiEmpty();
    final drafts = values
        .whereType<Map<String, dynamic>>()
        .map(_GeminiDraft.fromJson)
        .map((draft) => draft.toDraft())
        .where((draft) => draft.title.isNotEmpty)
        .take(20)
        .toList(growable: false);
    return drafts.isEmpty ? GeminiEmpty() : GeminiSuccess(drafts: drafts);
  }

  static String? _detectMimeType(String path) =>
      switch (path.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => null,
      };
}
