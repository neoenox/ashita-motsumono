// test/background_task_runner_reporter_failure_test.dart
// BackgroundTaskRunner のエラー報告処理が失敗した場合の封じ込めを検証する。
// 関連: lib/src/background_task_runner.dart, Issue #113

import 'package:ashita_motsumono/src/background_task_runner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundTaskRunner reporter failures', () {
    test('contains synchronous error-handler failures', () async {
      final failures = <
        (
          Object originalError,
          StackTrace originalStack,
          Object reportingError,
          StackTrace reportingStack,
          String taskName,
        )
      >[];
      final runner = BackgroundTaskRunner(
        onError: (_, _, _) {
          throw StateError('reporting failed');
        },
        onReporterFailure:
            (
              originalError,
              originalStack,
              reportingError,
              reportingStack,
              taskName,
            ) {
              failures.add((
                originalError,
                originalStack,
                reportingError,
                reportingStack,
                taskName,
              ));
            },
      );

      await expectLater(
        runner.run(
          name: 'notification rescheduling',
          action: () async => throw Exception('task failed'),
        ),
        completes,
      );

      expect(failures, hasLength(1));
      expect(failures.single.$1.toString(), 'Exception: task failed');
      expect(failures.single.$2.toString(), isNotEmpty);
      expect(failures.single.$3, isA<StateError>());
      expect(failures.single.$4.toString(), isNotEmpty);
      expect(failures.single.$5, 'notification rescheduling');
    });

    test('contains asynchronous error-handler failures', () async {
      var fallbackCalls = 0;
      final runner = BackgroundTaskRunner(
        onError: (_, _, _) async {
          await Future<void>.delayed(Duration.zero);
          throw StateError('async reporting failed');
        },
        onReporterFailure: (_, _, reportingError, _, taskName) async {
          await Future<void>.delayed(Duration.zero);
          expect(reportingError, isA<StateError>());
          expect(taskName, 'ad service initialization');
          fallbackCalls += 1;
        },
      );

      await expectLater(
        runner.run(
          name: 'ad service initialization',
          action: () async => throw Exception('task failed'),
        ),
        completes,
      );

      expect(fallbackCalls, 1);
    });

    test('contains failures from the reporter-failure handler', () async {
      final runner = BackgroundTaskRunner(
        onError: (_, _, _) {
          throw StateError('reporting failed');
        },
        onReporterFailure: (_, _, _, _, _) {
          throw StateError('fallback failed');
        },
      );

      await expectLater(
        runner.run(
          name: 'task',
          action: () async => throw Exception('task failed'),
        ),
        completes,
      );
    });

    test('contains exceptions thrown by FlutterError.onError', () async {
      final previousHandler = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previousHandler);

      FlutterError.onError = (_) {
        throw StateError('FlutterError.onError failed');
      };

      Object? capturedReportingError;
      final runner = BackgroundTaskRunner(
        onReporterFailure: (_, _, reportingError, reportingStack, taskName) {
          capturedReportingError = reportingError;
          expect(reportingStack.toString(), isNotEmpty);
          expect(taskName, 'default reporter task');
        },
      );

      await expectLater(
        runner.run(
          name: 'default reporter task',
          action: () async => throw Exception('task failed'),
        ),
        completes,
      );

      expect(capturedReportingError, isA<StateError>());
    });

    test('does not call error handlers when the task succeeds', () async {
      var errorCalls = 0;
      var fallbackCalls = 0;
      final runner = BackgroundTaskRunner(
        onError: (_, _, _) {
          errorCalls += 1;
        },
        onReporterFailure: (_, _, _, _, _) {
          fallbackCalls += 1;
        },
      );

      await runner.run(name: 'successful task', action: () async {});

      expect(errorCalls, 0);
      expect(fallbackCalls, 0);
    });
  });
}
