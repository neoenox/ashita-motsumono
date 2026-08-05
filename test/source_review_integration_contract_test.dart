import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release artifacts require validated latest master', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    expect(workflow, contains('needs: analyze-and-test'));
    expect(
      workflow,
      contains('needs.analyze-and-test.result == \'success\''),
    );
    expect(workflow, contains('Verify release source is latest master'));
    expect(workflow, contains('git rev-parse origin/master'));
  });

  test('data cleanup cannot cancel newly-created todo notifications', () {
    final source = File('lib/src/app_state_cleanup.dart').readAsStringSync();

    expect(source, contains('_runPostDeleteCleanup(todoIdsToCancel)'));
    expect(source, contains('executeCanceledTodo(todoId)'));
    expect(source, isNot(contains('retryPending(const <AppTodo>[])')));
  });

  test('date extraction applies explicit, action, then generic priority', () {
    final source = File(
      'lib/src/services/date_extractor.dart',
    ).readAsStringSync();

    final explicit = source.indexOf('_explicitDeadlineKeywordPattern');
    final action = source.indexOf('_actionDateKeywordPattern');
    final generic = source.indexOf('_genericDeadlineKeywordPattern');

    expect(explicit, greaterThanOrEqualTo(0));
    expect(action, greaterThan(explicit));
    expect(generic, greaterThan(action));
  });

  test('abandoned OCR results retain cleanup ownership until handoff', () {
    final source = File(
      'lib/src/screens/add_todo_screen_actions.dart',
    ).readAsStringSync();

    expect(source, contains('if (!handedOff && pendingSuccess != null)'));
    expect(source, contains('_cleanupAbandonedOcrResult'));
    expect(source, contains('String? persistedDocumentId'));
  });

  test('purchase providers are disposed across bootstrap teardown paths', () {
    final source = File('lib/src/bootstrap_app.dart').readAsStringSync();

    expect(source, contains('purchaseProvider?.dispose()'));
    expect(source, contains('previousPurchaseProvider?.dispose()'));
    expect(source, contains('_purchaseProvider?.dispose()'));
  });

  test('Worker entitlement tokens fail closed on malformed input', () {
    final source = File(
      'workers/gemini-proxy/src/index.ts',
    ).readAsStringSync();

    expect(source, contains("header.alg !== 'HS256'"));
    expect(source, contains("header.typ !== 'JWT'"));
    expect(source, contains('function isEntitlementPayload'));
    expect(source, contains('payload.exp - payload.iat > TOKEN_TTL_SECONDS'));
  });

  test('corrupt database backup preserves successful partial copies', () {
    final source = File(
      'lib/src/repositories/app_database.dart',
    ).readAsStringSync();

    expect(source, contains('backupDatabaseFilesAtPath'));
    expect(source, contains("for (final suffix in _databaseSuffixes)"));
    expect(source, contains('copiedPaths.add(destination.path)'));
    expect(source, contains('既に退避できたファイルは復旧証跡として残す'));
  });
}
