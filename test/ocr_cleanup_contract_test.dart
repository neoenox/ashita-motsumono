import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single-image OCR keeps cleanup ownership until navigation handoff', () {
    final source = File(
      'lib/src/screens/add_todo_screen_actions.dart',
    ).readAsStringSync();

    expect(source, contains('OcrPickSuccess? pendingSuccess'));
    expect(source, contains('var handedOff = false'));
    expect(
      source,
      contains('if (!handedOff && pendingSuccess != null)'),
    );
    expect(source, contains('_cleanupAbandonedOcrResult'));
  });

  test('AI OCR deletes a persisted document when handoff does not occur', () {
    final source = File(
      'lib/src/screens/add_todo_screen_actions.dart',
    ).readAsStringSync();

    expect(source, contains('String? persistedDocumentId'));
    expect(source, contains('await appState.deleteDocument(persistedDocumentId)'));
    expect(source, contains('await ImageFileService.deleteIfExists(path)'));
  });
}
