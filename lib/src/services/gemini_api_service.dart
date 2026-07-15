// lib/src/services/gemini_api_service.dart
// Gemini API に画像を送信し、構造化された Todo 抽出結果を受け取る。
// Cloudflare Workers プロキシ経由で呼び出し、APIキーはクライアント側に置かない。
// 関連: services/ocr_pick_service.dart, services/extraction_service.dart,
//       workers/gemini-proxy/src/index.ts

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/entities.dart';

/// Gemini API が JSON で返す1件の draft
class _GeminiDraft {
  _GeminiDraft({
    required this.title,
    required this.category,
    this.dueDate,
    this.amount,
    required this.items,
    this.note,
  });

  factory _GeminiDraft.fromJson(Map<String, dynamic> json) {
    return _GeminiDraft(
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      dueDate: json['dueDate'] as String?,
      amount: (json['amount'] as num?)?.toInt(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      note: json['note'] as String?,
    );
  }

  final String title;
  final String category;
  final String? dueDate;
  final int? amount;
  final List<String> items;
  final String? note;

  ExtractionDraft toDraft() {
    DateTime? parsedDate;
    if (dueDate != null && dueDate!.length == 10) {
      parsedDate = DateTime.tryParse(dueDate!);
    }
    return ExtractionDraft(
      title: title,
      category: _parseCategory(category),
      dueDate: parsedDate,
      amount: amount,
      items: items,
      note: note,
    );
  }

  static TodoCategory _parseCategory(String raw) {
    return switch (raw) {
      'payment' => TodoCategory.payment,
      'submit' => TodoCategory.submit,
      'event' => TodoCategory.event,
      'item' => TodoCategory.item,
      _ => TodoCategory.other,
    };
  }
}

/// Gemini API 呼び出し結果
sealed class GeminiResult {}

/// 成功: 抽出 draft リストを含む
class GeminiSuccess extends GeminiResult {
  GeminiSuccess({required this.drafts});

  final List<ExtractionDraft> drafts;
}

/// 空結果: テキストが抽出できたが Todo 情報が含まれていなかった
class GeminiEmpty extends GeminiResult {}

/// エラー
class GeminiError extends GeminiResult {
  GeminiError(this.message);

  final String message;
}

/// Gemini API に画像を送信し、構造化データを取得するサービス。
///
/// [proxyUrl] には Cloudflare Workers プロキシの URL を指定する。
/// release build では `--dart-define=GEMINI_PROXY_URL=...` で本番URLを渡すこと。
class GeminiApiService {
  GeminiApiService({this.proxyUrl});

  String? proxyUrl;

  static const _defaultProxyUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
    defaultValue: '',
  );

  factory GeminiApiService.defaultInstance() =>
      GeminiApiService(proxyUrl: _defaultProxyUrl);

  /// proxy URL が未設定か localhost の場合に true を返す。
  static bool _isUnconfigured(String? url) {
    if (url == null || url.isEmpty) return true;
    try {
      final uri = Uri.parse(url);
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') return true;
    } on Object {
      return true;
    }
    return false;
  }

  /// 画像ファイルを Gemini API で解析し、抽出 draft を返す。
  Future<GeminiResult> analyzeImage(File imageFile) async {
    final url = proxyUrl ?? _defaultProxyUrl;

    // release build で localhost のまま事故を防ぐ
    if (_isUnconfigured(url)) {
      return GeminiError('AI解析サーバーが設定されていません');
    }

    if (!await imageFile.exists()) {
      return GeminiError('画像ファイルが見つかりません');
    }

    final mimeType = _detectMimeType(imageFile.path);

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Data = base64Encode(bytes);

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      const timezone = 'Asia/Tokyo';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageBase64': base64Data,
          'mimeType': mimeType,
          'today': todayStr,
          'timezone': timezone,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final detail = _extractError(response.body);
        return GeminiError('APIエラー ($detail)');
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
    } on Object catch (e) {
      return GeminiError('予期せぬエラーが発生しました: $e');
    }
  }

  GeminiResult _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      // Gemini API のエラーレスポンス
      if (json.containsKey('error')) {
        final error = json['error'] as Map<String, dynamic>?;
        final message = error?['message'] as String? ?? '不明なエラー';
        return GeminiError(message);
      }

      // candidates[] からテキストを取り出す
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return GeminiEmpty();
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        return GeminiEmpty();
      }

      final text = parts.first['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        return GeminiEmpty();
      }

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final draftsJson = parsed['drafts'] as List<dynamic>?;
      if (draftsJson == null || draftsJson.isEmpty) {
        return GeminiEmpty();
      }

      final drafts = draftsJson
          .map((e) => _GeminiDraft.fromJson(e as Map<String, dynamic>).toDraft())
          .where((d) => d.title.isNotEmpty)
          .toList(growable: false);

      if (drafts.isEmpty) return GeminiEmpty();
      return GeminiSuccess(drafts: drafts);
    } on FormatException {
      return GeminiEmpty();
    } on Object {
      return GeminiEmpty();
    }
  }

  String _extractError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as String?;
      if (error != null) return error;
      final message = json['message'] as String?;
      if (message != null) return message;
      return body.length > 100 ? '${body.substring(0, 100)}...' : body;
    } catch (_) {
      return body.length > 100 ? '${body.substring(0, 100)}...' : body;
    }
  }

  static String _detectMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
