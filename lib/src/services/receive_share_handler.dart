// lib/src/services/receive_share_handler.dart
// 他アプリからの共有Intent（画像・PDF・テキスト）を受信し、OCR/抽出処理を実行する。

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../utils/text_fingerprint.dart';
import 'app_settings.dart';
import 'document_intake_service.dart';
import 'extraction_service.dart';
import 'image_file_service.dart';
import 'ocr_service.dart';
import 'share_file_staging_service.dart';

part 'receive_share_handler_runtime.dart';
part 'receive_share_handler_sources.dart';
part 'receive_share_handler_state.dart';

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
  pdfImportFailed,
  disposed,
  unexpected,
}

sealed class ReceiveShareResult {
  const ReceiveShareResult();
}

final class ReceiveShareSuccess extends ReceiveShareResult {
  const ReceiveShareSuccess({
    required this.drafts,
    required this.documentId,
    this.ocrText,
  });

  final List<ExtractionDraft> drafts;
  final String documentId;

  /// 候補ゼロ時に手入力画面へ引き継ぐOCR全文。
  final String? ocrText;
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
    DocumentIntakeService? documentIntakeService,
    ShareFileStagingService? shareFileStagingService,
  }) : _appState = appState,
       _appSettings = appSettings,
       _imageFileService = imageFileService ?? ImageFileService(),
       _ocrService = ocrService ?? OcrService(),
       _documentIntakeService =
           documentIntakeService ??
           DocumentIntakeService(appState: appState, appSettings: appSettings),
       _shareFileStagingService =
           shareFileStagingService ?? ShareFileStagingService();

  final AppState _appState;
  final AppSettings _appSettings;
  final ImageFileService _imageFileService;
  final OcrService _ocrService;
  final DocumentIntakeService _documentIntakeService;
  final ShareFileStagingService _shareFileStagingService;

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
}
