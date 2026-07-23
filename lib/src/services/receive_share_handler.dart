// lib/src/services/receive_share_handler.dart
// 他アプリからの共有Intent（画像・テキスト）を受信し、OCR/抽出処理を実行する。
// 二重取込防止（処理中フラグ＋fingerprint）、エラー分類、直列キューイングを備える。
// 関連: home_screen.dart, ocr_service.dart, extraction_service.dart, ../utils/text_fingerprint.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../utils/text_fingerprint.dart';
import 'app_settings.dart';
import 'extraction_service.dart';
import 'image_file_service.dart';
import 'ocr_service.dart';

enum ReceiveShareFailureKind {
  busy,
  duplicate,
  imageReadFailed,
  ocrEmpty,
  extractionEmpty,
  imageTooLarge,
  unsupportedFormat,
  textEmpty,
  saveFailed,
  disposed,
  unexpected,
}

sealed class ReceiveShareResult {
  const ReceiveShareResult();
}

final class ReceiveShareSuccess extends ReceiveShareResult {
  const ReceiveShareSuccess({required this.drafts, required this.documentId});

  final List<ExtractionDraft> drafts;
  final String documentId;
}

final class ReceiveShareFailure extends ReceiveShareResult {
  const ReceiveShareFailure(this.message, {this.kind});

  final String message;
  final ReceiveShareFailureKind? kind;
}

typedef ReceiveShareResultCallback =
    Future<void> Function(ReceiveShareResult result);

typedef ReceiveShareErrorCallback =
    void Function(Object error, StackTrace stackTrace);

class _CompletedFingerprint {
  const _CompletedFingerprint(this.value, this.expiresAt);

  final String value;
  final DateTime expiresAt;
}

class ReceiveShareHandler {
  ReceiveShareHandler({
    required AppState appState,
    required AppSettings appSettings,
    ImageFileService? imageFileService,
    OcrService? ocrService,
  }) : _appState = appState,
       _appSettings = appSettings,
       _imageFileService = imageFileService ?? ImageFileService(),
       _ocrService = ocrService ?? OcrService();

  final AppState _appState;
  final AppSettings _appSettings;
  final ImageFileService _imageFileService;
  final OcrService _ocrService;

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  Future<void> _queue = Future<void>.value();

  bool _started = false;
  bool _disposed = false;
  bool _isProcessing = false;

  String? _lastPayloadKey;
  DateTime? _lastPayloadAt;

  final List<_CompletedFingerprint> _completedFingerprints = [];
  static const _maxCompletedFingerprints = 128;
  static const _fingerprintTtl = Duration(hours: 1);

  static const _maxImageBytes = 5 * 1024 * 1024;

  Future<void> start({
    required ReceiveShareResultCallback onResult,
    required ReceiveShareErrorCallback onError,
  }) async {
    if (_started || _disposed) return;
    _started = true;

    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        _enqueue(files, onResult: onResult, onError: onError);
      },
      onError: (Object error) {
        onError(error, StackTrace.current);
      },
    );

    try {
      final initialFiles = await ReceiveSharingIntent.instance
          .getInitialMedia();

      _enqueue(initialFiles, onResult: onResult, onError: onError);

      await _queue;
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }

  void _enqueue(
    List<SharedMediaFile> files, {
    required ReceiveShareResultCallback onResult,
    required ReceiveShareErrorCallback onError,
  }) {
    _queue = _queue.then((_) async {
      if (_disposed) return;

      try {
        await _processIncoming(files, onResult: onResult);
      } on Object catch (error, stackTrace) {
        onError(error, stackTrace);
      }
    });
  }

  Future<void> _processIncoming(
    List<SharedMediaFile> files, {
    required ReceiveShareResultCallback onResult,
  }) async {
    if (files.isEmpty) return;

    final payloadKey = files
        .map((file) => '${file.type.name}:${file.path}')
        .join('\u001f');
    final now = DateTime.now();

    final recentDuplicate =
        _lastPayloadKey == payloadKey &&
        _lastPayloadAt != null &&
        now.difference(_lastPayloadAt!) < const Duration(seconds: 2);

    if (recentDuplicate) {
      await _resetSafely();
      return;
    }

    _lastPayloadKey = payloadKey;
    _lastPayloadAt = now;

    if (_isProcessing) {
      await _resetSafely();
      await onResult(
        const ReceiveShareFailure(
          '現在処理中の共有があります。完了してから再度お試しください。',
          kind: ReceiveShareFailureKind.busy,
        ),
      );
      return;
    }

    ReceiveShareResult? result;

    try {
      result = await process(files);
    } finally {
      await _resetSafely();
    }

    if (result != null && !_disposed) {
      await onResult(result);
    }
  }

  Future<ReceiveShareResult?> process(List<SharedMediaFile> files) async {
    SharedMediaFile? supportedFile;
    String? mimeType;

    for (final file in files) {
      if (file.path.trim().isEmpty) continue;

      if (file.type == SharedMediaType.image ||
          file.type == SharedMediaType.text) {
        supportedFile = file;
        mimeType = file.type == SharedMediaType.image
            ? 'image/*'
            : 'text/plain';
        break;
      }
    }

    if (supportedFile == null) {
      return const ReceiveShareFailure(
        '対応している共有データは画像またはテキストです。',
        kind: ReceiveShareFailureKind.unsupportedFormat,
      );
    }

    _isProcessing = true;

    try {
      _evictExpiredFingerprints();

      if (supportedFile.type == SharedMediaType.image) {
        return await _processImage(supportedFile.path, mimeType: mimeType);
      }

      return await _processText(supportedFile.path);
    } on OcrException catch (error) {
      return ReceiveShareFailure(
        error.message,
        kind: ReceiveShareFailureKind.ocrEmpty,
      );
    } on StateError catch (error) {
      return ReceiveShareFailure(
        error.message,
        kind: ReceiveShareFailureKind.unexpected,
      );
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ReceiveShareHandler: import failed: '
          '$error\n$stackTrace',
        );
      }

      return const ReceiveShareFailure(
        '共有データの取り込みに失敗しました。',
        kind: ReceiveShareFailureKind.unexpected,
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<ReceiveShareResult> _processText(String rawText) async {
    final text = rawText.trim();

    if (text.isEmpty) {
      return const ReceiveShareFailure(
        '共有されたテキストが空です。',
        kind: ReceiveShareFailureKind.textEmpty,
      );
    }

    final fingerprint = TextFingerprint.calculate(text);
    if (_isCompleted(fingerprint)) {
      return const ReceiveShareFailure(
        'このテキストは既に取り込み済みです。',
        kind: ReceiveShareFailureKind.duplicate,
      );
    }

    final drafts = ExtractionService.extractMany(
      text,
      learnedItemLabels: _appSettings.learnedItemLabels,
    );

    if (drafts.isEmpty) {
      return const ReceiveShareFailure(
        '共有テキストから日付や持ち物を抽出できませんでした。',
        kind: ReceiveShareFailureKind.extractionEmpty,
      );
    }

    try {
      final document = await _appState.addDocument(
        sourceType: 'shared_text',
        ocrText: text,
      );

      _recordCompleted(fingerprint);

      return ReceiveShareSuccess(drafts: drafts, documentId: document.id);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ReceiveShareHandler: save failed: '
          '$error\n$stackTrace',
        );
      }

      return const ReceiveShareFailure(
        'テキストの保存に失敗しました。',
        kind: ReceiveShareFailureKind.saveFailed,
      );
    }
  }

  Future<ReceiveShareResult> _processImage(
    String sourcePath, {
    String? mimeType,
  }) async {
    final source = XFile(sourcePath, mimeType: mimeType);

    int sourceLength;
    try {
      sourceLength = await source.length();
    } on Object {
      return const ReceiveShareFailure(
        '画像を読み込めませんでした。対応形式（JPEG/PNG）か確認してください。',
        kind: ReceiveShareFailureKind.imageReadFailed,
      );
    }

    if (sourceLength <= 0) {
      return const ReceiveShareFailure(
        '共有された画像が空です。',
        kind: ReceiveShareFailureKind.imageReadFailed,
      );
    }

    if (sourceLength > _maxImageBytes) {
      return const ReceiveShareFailure(
        '画像サイズが大きすぎます（上限5MB）。縮小してから共有してください。',
        kind: ReceiveShareFailureKind.imageTooLarge,
      );
    }

    File copiedImage;
    try {
      copiedImage = await _imageFileService.copyFromXFile(source);
    } on Object {
      return const ReceiveShareFailure(
        '画像の保存に失敗しました。',
        kind: ReceiveShareFailureKind.saveFailed,
      );
    }

    try {
      final ocrText = await _ocrService.recognize(copiedImage);

      if (ocrText.trim().isEmpty) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        return const ReceiveShareFailure(
          '画像から文字が見つかりませんでした。'
          '文字がはっきり写った画像を共有してください。',
          kind: ReceiveShareFailureKind.ocrEmpty,
        );
      }

      final ocrFingerprint = TextFingerprint.calculate(ocrText);
      if (_isCompleted(ocrFingerprint)) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        return const ReceiveShareFailure(
          'この画像は既に取り込み済みです。',
          kind: ReceiveShareFailureKind.duplicate,
        );
      }

      final drafts = ExtractionService.extractMany(
        ocrText,
        learnedItemLabels: _appSettings.learnedItemLabels,
      );

      if (drafts.isEmpty) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        return const ReceiveShareFailure(
          '画像からTodo情報を抽出できませんでした。'
          '日付や持ち物が含まれているか確認してください。',
          kind: ReceiveShareFailureKind.extractionEmpty,
        );
      }

      try {
        final document = await _appState.addDocument(
          sourceType: 'shared_image',
          localImagePath: copiedImage.path,
          ocrText: ocrText,
        );

        _recordCompleted(ocrFingerprint);

        return ReceiveShareSuccess(drafts: drafts, documentId: document.id);
      } on Object catch (error, stackTrace) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        if (kDebugMode) {
          debugPrint(
            'ReceiveShareHandler: save failed: '
            '$error\n$stackTrace',
          );
        }

        return const ReceiveShareFailure(
          '画像の保存に失敗しました。',
          kind: ReceiveShareFailureKind.saveFailed,
        );
      }
    } on Object {
      await ImageFileService.deleteIfExists(copiedImage.path);
      rethrow;
    }
  }

  bool _isCompleted(String fingerprint) {
    final now = DateTime.now();
    return _completedFingerprints.any(
      (f) => f.value == fingerprint && f.expiresAt.isAfter(now),
    );
  }

  void _recordCompleted(String fingerprint) {
    _completedFingerprints.add(
      _CompletedFingerprint(fingerprint, DateTime.now().add(_fingerprintTtl)),
    );

    while (_completedFingerprints.length > _maxCompletedFingerprints) {
      _completedFingerprints.removeAt(0);
    }
  }

  void _evictExpiredFingerprints() {
    final now = DateTime.now();
    _completedFingerprints.removeWhere((f) => !f.expiresAt.isAfter(now));
  }

  Future<void> _resetSafely() async {
    try {
      await ReceiveSharingIntent.instance.reset();
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ReceiveShareHandler: reset failed: '
          '$error\n$stackTrace',
        );
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _subscription?.cancel();
    _subscription = null;

    await _resetSafely();
  }
}
