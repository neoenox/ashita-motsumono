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
    var supportedIsPdf = false;

    for (final file in files) {
      if (file.path.trim().isEmpty) continue;
      final isPdf = _isPdfPath(file.path);
      if (file.type == SharedMediaType.image ||
          file.type == SharedMediaType.text ||
          isPdf) {
        supportedFile = file;
        supportedIsPdf = isPdf;
        mimeType = isPdf
            ? 'application/pdf'
            : file.type == SharedMediaType.image
            ? 'image/*'
            : 'text/plain';
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
      if (supportedIsPdf) return await _processPdf(supportedFile.path);
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
