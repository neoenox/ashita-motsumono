import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending side effects use a locked public API and unlocked internal path',
    () {
      final appState = File('lib/src/app_state.dart').readAsStringSync();
      final todos = File('lib/src/app_state_todos.dart').readAsStringSync();

      expect(
        appState,
        contains('Future<void> _retryPendingSideEffectsUnlocked()'),
      );
      expect(
        appState,
        contains('_runMutation(_retryPendingSideEffectsUnlocked)'),
      );
      expect(todos, contains('await _retryPendingSideEffectsUnlocked();'));
      expect(todos, isNot(contains('await retryPendingSideEffects();')));
    },
  );

  test('crash logging uses synchronous rotation and writes', () {
    final source = File(
      'lib/src/services/crash_reporter.dart',
    ).readAsStringSync();

    expect(source, contains('void _rotateIfNeededSync(File file)'));
    expect(source, contains('writeAsStringSync('));
    expect(
      source,
      isNot(
        contains('FlutterError.onError = (FlutterErrorDetails details) async'),
      ),
    );
  });

  test('worker caches and deduplicates Google OAuth tokens', () {
    final source = File('workers/gemini-proxy/src/index.ts').readAsStringSync();

    expect(source, contains('cachedGoogleAccessToken.expiresAt > now + 60'));
    expect(source, contains('pendingGoogleAccessToken'));
    expect(source, contains('expires_in?: number'));
    expect(source, contains("pem.replace(/\\\\n/g, '\\n')"));
  });
}
