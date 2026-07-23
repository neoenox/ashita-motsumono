import 'dart:async';

/// 購入・復元・検証イベントを受信順に直列実行する。
class PurchaseEventQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(FutureOr<T> Function() action) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await action());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
