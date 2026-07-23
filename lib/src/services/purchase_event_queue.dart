import 'dart:async';

/// 購入・復元・検証イベントを受信順に直列実行する。
class PurchaseEventQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> enqueue(FutureOr<void> Function() action) {
    final result = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await action();
        result.complete();
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<T> enqueueValue<T>(FutureOr<T> Function() action) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final value = await action();
        result.complete(value);
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
