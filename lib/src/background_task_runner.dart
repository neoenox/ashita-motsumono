// lib/src/background_task_runner.dart
// アプリ起動後のバックグラウンドタスク実行を安全に行うヘルパー。
// タスク例外とエラー報告処理の二次例外を明示的に捕捉する。
// 関連: bootstrap_app.dart, Issue #113

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Background task error handler signature.
typedef BackgroundErrorHandler =
    FutureOr<void> Function(
      Object error,
      StackTrace stackTrace,
      String taskName,
    );

/// Handles a failure raised while reporting the original task failure.
typedef BackgroundReporterFailureHandler =
    FutureOr<void> Function(
      Object originalError,
      StackTrace originalStackTrace,
      Object reportingError,
      StackTrace reportingStackTrace,
      String taskName,
    );

/// Runs a named background task, catching and reporting exceptions.
///
/// Used after application startup to prevent unhandled async errors
/// from background work (notification rescheduling, ad initialization, etc.).
class BackgroundTaskRunner {
  const BackgroundTaskRunner({
    BackgroundErrorHandler? onError,
    BackgroundReporterFailureHandler? onReporterFailure,
  }) : _onError = onError ?? _defaultErrorHandler,
       _onReporterFailure = onReporterFailure ?? _defaultReporterFailureHandler;

  final BackgroundErrorHandler _onError;
  final BackgroundReporterFailureHandler _onReporterFailure;

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

  static void _defaultReporterFailureHandler(
    Object originalError,
    StackTrace originalStackTrace,
    Object reportingError,
    StackTrace reportingStackTrace,
    String taskName,
  ) {
    try {
      debugPrint(
        'Failed to report bootstrap background task error ($taskName): '
        '$reportingError\n$reportingStackTrace\n'
        'Original error: $originalError\n$originalStackTrace',
      );
    } on Object {
      // Final containment boundary: never let diagnostics create another
      // unhandled error for an intentionally detached background task.
    }
  }

  /// Executes [action] as a background task identified by [name].
  ///
  /// If [action] throws, the exception and stack trace are forwarded to
  /// the error handler. Failures raised by the error handler are forwarded
  /// to the reporter-failure handler and are never allowed to escape.
  Future<void> run({
    required String name,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      try {
        await _onError(error, stackTrace, name);
      } on Object catch (reportingError, reportingStackTrace) {
        try {
          await _onReporterFailure(
            error,
            stackTrace,
            reportingError,
            reportingStackTrace,
            name,
          );
        } on Object {
          // Final containment boundary. The caller intentionally detaches
          // this Future with unawaited(), so no exception may escape here.
        }
      }
    }
  }
}
