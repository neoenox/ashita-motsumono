// test/bootstrap_background_task_test.dart
// BackgroundTaskRunner の例外捕捉、エラー報告、独立実行を検証する。
// 関連: lib/src/background_task_runner.dart, lib/src/bootstrap_app.dart, Issue #113

import 'package:ashita_motsumono/src/background_task_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundTaskRunner.run', () {
    test('catches exceptions from actions', () async {
      final errors = <(Object error, StackTrace stack, String name)>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add((error, stackTrace, name));
        },
      );

      await runner.run(
        name: 'test task',
        action: () async => throw Exception('test error'),
      );

      expect(errors, hasLength(1));
      expect(errors[0].$1, isA<Exception>());
      expect(errors[0].$1.toString(), 'Exception: test error');
      expect(errors[0].$3, 'test task');
    });

    test('preserves stack trace from exceptions', () async {
      StackTrace? capturedStack;
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          capturedStack = stackTrace;
        },
      );

      await runner.run(
        name: 'test task',
        action: () async => throw Exception('with trace'),
      );

      expect(capturedStack, isNotNull);
      expect(capturedStack.toString(), isNotEmpty);
    });

    test('does not report when action succeeds', () async {
      final errors = <String>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add(name);
        },
      );

      await runner.run(
        name: 'test task',
        action: () async {
          /* success */
        },
      );

      expect(errors, isEmpty);
    });

    test('reports the task name in error handler', () async {
      String? capturedName;
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          capturedName = name;
        },
      );

      await runner.run(
        name: 'notification rescheduling',
        action: () async => throw Exception('fail'),
      );

      expect(capturedName, 'notification rescheduling');
    });

    test('runs multiple tasks independently', () async {
      final executed = <String>[];
      final errors = <String>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add(name);
        },
      );

      // First task fails, second should still run
      await Future.wait([
        runner.run(
          name: 'task-a',
          action: () async {
            executed.add('task-a');
            throw Exception('task-a failed');
          },
        ),
        runner.run(
          name: 'task-b',
          action: () async {
            executed.add('task-b');
          },
        ),
      ]);

      expect(executed, containsAll(['task-a', 'task-b']));
      expect(errors, ['task-a']);
    });

    test('handles synchronous exceptions', () async {
      final errors = <String>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add(name);
        },
      );

      await runner.run(
        name: 'sync task',
        action: () {
          // ignore: only_throw_errors
          throw 'sync error';
        },
      );

      expect(errors, ['sync task']);
    });

    test('handles exceptions thrown after await', () async {
      final errors = <Object>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add(error);
        },
      );

      await runner.run(
        name: 'async task',
        action: () async {
          await Future<void>.delayed(Duration.zero);
          throw StateError('async error');
        },
      );

      expect(errors, hasLength(1));
      expect(errors[0], isA<StateError>());
    });

    test('catches errors thrown by non-Exception objects', () async {
      final errors = <Object>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add(error);
        },
      );

      await runner.run(
        name: 'string throw',
        action: () async => throw 'raw string error',
      );

      expect(errors, hasLength(1));
      expect(errors[0], 'raw string error');
    });

    test('returns normally even when action throws', () async {
      final runner = BackgroundTaskRunner(onError: (_, _, _) {});

      // Should not throw — completes normally despite action failure
      await runner.run(
        name: 'task',
        action: () async => throw Exception('error'),
      );
    });
  });

  group('BackgroundTaskRunner independence', () {
    test('second task runs after first task failure', () async {
      final callOrder = <String>[];
      final runner = BackgroundTaskRunner(onError: (_, _, _) {});

      // Start first task (will fail)
      final first = runner.run(
        name: 'first',
        action: () async {
          callOrder.add('first');
          throw Exception('first failed');
        },
      );

      // Start second task (should succeed independently)
      final second = runner.run(
        name: 'second',
        action: () async {
          callOrder.add('second');
        },
      );

      await Future.wait([first, second]);

      expect(callOrder, ['first', 'second']);
    });

    test('both tasks report errors independently', () async {
      final errors = <String>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add(name);
        },
      );

      await Future.wait([
        runner.run(
          name: 'task-1',
          action: () async => throw Exception('error 1'),
        ),
        runner.run(
          name: 'task-2',
          action: () async => throw Exception('error 2'),
        ),
      ]);

      expect(errors, containsAll(['task-1', 'task-2']));
    });

    test('no errors when all tasks succeed', () async {
      final errors = <String>[];
      final runner = BackgroundTaskRunner(
        onError: (error, stackTrace, name) {
          errors.add(name);
        },
      );

      await Future.wait([
        runner.run(name: 'task-a', action: () async {}),
        runner.run(name: 'task-b', action: () async {}),
      ]);

      expect(errors, isEmpty);
    });
  });

  group('BackgroundTaskRunner default handler', () {
    test('default handler does not throw', () async {
      final runner = BackgroundTaskRunner();

      // Should not throw even without custom error handler
      await runner.run(
        name: 'default handler task',
        action: () async => throw Exception('default handler test'),
      );
    });
  });
}
