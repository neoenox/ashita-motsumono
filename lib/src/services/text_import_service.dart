// lib/src/services/text_import_service.dart
// 共有メニュー/クリップボードからのテキスト取り込みを管理するサービス
// なぜ存在するか: receive_sharing_intentとクリップボードの処理を一元管理するため
// 関連: add_todo_screen.dart, extraction_service.dart, text_fingerprint.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/entities.dart';
import 'extraction_service.dart';
import '../utils/text_fingerprint.dart';

/// 取り込み元の種別
enum ImportSource { shareIntent, clipboard }

/// テキスト取り込み結果
sealed class TextImportResult {
  const TextImportResult();
}

/// 抽出成功
class TextImportSuccess extends TextImportResult {
  const TextImportSuccess({
    required this.drafts,
    required this.rawText,
    required this.fingerprint,
    required this.source,
  });

  final List<ExtractionDraft> drafts;
  final String rawText;
  final String fingerprint;
  final ImportSource source;
}

/// 抽出失败（テキストからTodoを生成できなかった）
class TextImportEmpty extends TextImportResult {
  const TextImportEmpty({required this.source});
  final ImportSource source;
}

/// 共有インテント受信ストリームを管理
class TextImportService {
  TextImportService({required this.learnedItemLabels});

  final List<String> learnedItemLabels;
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final _controller = StreamController<TextImportResult>.broadcast();

  /// 共有テキストのストリーム（外部でlistenする）
  Stream<TextImportResult> get onImport => _controller.stream;

  /// 共有インテントのリスナーを開始
  void startListening() {
    // アプリ起動中に共有されたテキスト
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleFiles,
      onError: (Object e) {
        if (kDebugMode) debugPrint('ReceiveSharingIntent error: $e');
      },
    );

    // アプリ起動時に共有されたテキスト
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleFiles);
  }

  void _handleFiles(List<SharedMediaFile> files) {
    for (final file in files) {
      if (file.type != SharedMediaType.text) continue;
      final path = file.path;
      if (path.isEmpty) continue;
      _processText(path, ImportSource.shareIntent);
    }
  }

  /// テキストを処理して結果を流す
  void _processText(String text, ImportSource source) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final drafts = ExtractionService.extractMany(
      trimmed,
      learnedItemLabels: learnedItemLabels,
    );

    if (drafts.isEmpty) {
      _controller.add(TextImportEmpty(source: source));
      return;
    }

    _controller.add(
      TextImportSuccess(
        drafts: drafts,
        rawText: trimmed,
        fingerprint: TextFingerprint.calculate(trimmed),
        source: source,
      ),
    );
  }

  /// クリップボードからテキストを読み込んで処理
  Future<void> importFromClipboard(String? clipboardText) async {
    final trimmed = clipboardText?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _controller.add(const TextImportEmpty(source: ImportSource.clipboard));
      return;
    }
    _processText(trimmed, ImportSource.clipboard);
  }

  /// リスナーを解放
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
