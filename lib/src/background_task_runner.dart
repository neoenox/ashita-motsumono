// lib/src/background_task_runner.dart
// アプリ起動後のバックグラウンドタスク実行を安全に行うヘルパー。
// 例外を明示的に捕捉し、FlutterError.reportError へ渡す。
// 関連: bootstrap_app.dart, Issue #113

import 'package:flutter/foundation.dart';

/// Background task error handler signature.
typedef BackgroundErrorHandler =
    void Function(Object error, StackTrace stackTrace, String taskName);

/// Runs a named background task, catching and reporting exceptions.
///
/// Used after application startup to prevent unhandled async errors
/// from background work (notification rescheduling, ad initialization, etc.).
class BackgroundTaskRunner {
  const BackgroundTaskRunner({BackgroundErrorHandler? onError})
    : _onError = onError ?? _defaultErrorHandler;

  final BackgroundErrorHandler _onError;

  static void _defaultErrorHandler(
    Object error,
    StackTrace stackTrace,
    String taskName,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bootstrap',
        context: ErrorDescription(
          'while running $taskName after application startup',
        ),
      ),
    );
  }

  /// Executes [action] as a background task identified by [name].
  ///
  /// If [action] throws, the exception and stack trace are forwarded to
  /// the error handler instead of becoming an unhandled async error.
  Future<void> run({
    required String name,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace, name);
    }
  }
}
