part of 'receive_share_handler.dart';

extension ReceiveShareHandlerRuntime on ReceiveShareHandler {
  Future<void> start({
    required ReceiveShareResultCallback onResult,
    required ReceiveShareErrorCallback onError,
  }) async {
    if (_started || _disposed) return;
    _started = true;

    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => _enqueue(files, onResult: onResult, onError: onError),
      onError: (Object error) => onError(error, StackTrace.current),
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
        .map((file) => '${file.type.name}:${file.mimeType ?? ''}:${file.path}')
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
    final nonEmptyFiles = files
        .where((file) => file.path.trim().isNotEmpty)
        .toList(growable: false);
    if (nonEmptyFiles.isEmpty) {
      return const ReceiveShareFailure(
        '対応している共有データは画像、PDF、テキストです。',
        kind: ReceiveShareFailureKind.unsupportedFormat,
      );
    }

    final imageFiles = nonEmptyFiles
        .where(_isImageFile)
        .toList(growable: false);
    final pdfFiles = nonEmptyFiles.where(_isPdfFile).toList(growable: false);

    if (imageFiles.isNotEmpty && pdfFiles.isNotEmpty) {
      return const ReceiveShareFailure(
        '画像とPDFの同時共有は対応していません。',
        kind: ReceiveShareFailureKind.unsupportedFormat,
      );
    }
    if (pdfFiles.length > 1) {
      return const ReceiveShareFailure(
        'PDFは1ファイルずつ共有してください。',
        kind: ReceiveShareFailureKind.unsupportedFormat,
      );
    }

    SharedMediaFile? supportedFile;
    for (final file in nonEmptyFiles) {
      if (_isImageFile(file) || _isPdfFile(file) || _isTextFile(file)) {
        supportedFile = file;
        break;
      }
    }

    if (supportedFile == null) {
      return const ReceiveShareFailure(
        '対応している共有データは画像、PDF、テキストです。',
        kind: ReceiveShareFailureKind.unsupportedFormat,
      );
    }

    _isProcessing = true;
    try {
      _evictExpiredFingerprints();
      if (_isPdfFile(supportedFile)) {
        return await _processPdf(supportedFile);
      }
      if (_isImageFile(supportedFile)) {
        if (imageFiles.length == 1) {
          return await _processImage(
            supportedFile.path,
            mimeType: supportedFile.mimeType ?? 'image/*',
          );
        }
        return await _processMultipleImages(imageFiles);
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
        debugPrint('ReceiveShareHandler: import failed: $error\n$stackTrace');
      }
      return const ReceiveShareFailure(
        '共有データの取り込みに失敗しました。',
        kind: ReceiveShareFailureKind.unexpected,
      );
    } finally {
      _isProcessing = false;
    }
  }
}
