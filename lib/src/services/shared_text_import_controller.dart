// lib/src/services/shared_text_import_controller.dart
// 共有テキスト/クリップボード取り込みのUI状態を管理するChangeNotifier
// なぜ存在するか: TextImportServiceのストリーム結果をProvider経由で画面に反映するため
// 関連: text_import_service.dart, add_todo_screen.dart, app_state.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/entities.dart';
import '../app_state.dart';
import 'text_import_service.dart';

/// テキスト取り込みのUI状態
sealed class SharedTextImportState {
  const SharedTextImportState();
}

class SharedTextImportIdle extends SharedTextImportState {
  const SharedTextImportIdle();
}

class SharedTextImportProcessing extends SharedTextImportState {
  const SharedTextImportProcessing();
}

class SharedTextImportSuccess extends SharedTextImportState {
  const SharedTextImportSuccess({
    required this.drafts,
    required this.documentId,
    required this.source,
  });

  final List<ExtractionDraft> drafts;
  final String documentId;
  final ImportSource source;
}

class SharedTextImportEmpty extends SharedTextImportState {
  const SharedTextImportEmpty({required this.source});
  final ImportSource source;
}

class SharedTextImportError extends SharedTextImportState {
  const SharedTextImportError(this.message);
  final String message;
}

class SharedTextImportController extends ChangeNotifier {
  SharedTextImportController({
    required AppState appState,
    required List<String> learnedItemLabels,
  }) : _appState = appState,
       _service = TextImportService(learnedItemLabels: learnedItemLabels);

  final AppState _appState;
  final TextImportService _service;
  StreamSubscription<TextImportResult>? _subscription;

  SharedTextImportState _state = const SharedTextImportIdle();
  SharedTextImportState get state => _state;

  /// 共有インテントのリスナーを開始し、結果をストリームで監視
  void startListening() {
    _subscription = _service.onImport.listen(_onImportResult);
    _service.startListening();
  }

  /// クリップボードから取り込み
  Future<void> importFromClipboard(String? text) async {
    _updateState(const SharedTextImportProcessing());
    await _service.importFromClipboard(text);
  }

  /// 処理結果をハンドリングし、DBにDocumentを保存
  Future<void> _onImportResult(TextImportResult result) async {
    switch (result) {
      case TextImportSuccess(:final drafts, :final rawText, :final source):
        try {
          final document = await _appState.addDocument(
            sourceType: source == ImportSource.shareIntent
                ? 'sharedText'
                : 'text',
            ocrText: rawText,
          );
          _updateState(
            SharedTextImportSuccess(
              drafts: drafts,
              documentId: document.id,
              source: source,
            ),
          );
        } catch (e) {
          _updateState(SharedTextImportError('ドキュメント保存に失敗しました: $e'));
        }
      case TextImportEmpty(:final source):
        _updateState(SharedTextImportEmpty(source: source));
    }
  }

  void _updateState(SharedTextImportState newState) {
    _state = newState;
    notifyListeners();
  }

  /// 状態をリセット（画面遷移後に呼ぶ）
  void reset() {
    _updateState(const SharedTextImportIdle());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
