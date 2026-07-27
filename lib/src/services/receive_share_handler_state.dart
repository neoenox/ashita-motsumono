part of 'receive_share_handler.dart';

extension ReceiveShareHandlerLifecycle on ReceiveShareHandler {
  bool _isCompleted(String fingerprint) {
    final now = DateTime.now();
    return _completedFingerprints.any(
      (entry) => entry.value == fingerprint && entry.expiresAt.isAfter(now),
    );
  }

  void _recordCompleted(String fingerprint) {
    _completedFingerprints.add(
      _CompletedFingerprint(fingerprint, DateTime.now().add(ReceiveShareHandler._fingerprintTtl)),
    );
    while (_completedFingerprints.length > ReceiveShareHandler._maxCompletedFingerprints) {
      _completedFingerprints.removeAt(0);
    }
  }

  void _evictExpiredFingerprints() {
    final now = DateTime.now();
    _completedFingerprints.removeWhere(
      (entry) => !entry.expiresAt.isAfter(now),
    );
  }

  Future<void> _resetSafely() async {
    try {
      await ReceiveSharingIntent.instance.reset();
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ReceiveShareHandler: reset failed: $error\n$stackTrace');
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
