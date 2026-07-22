// test/services/text_import_service_test.dart
//
// TextImportService のユニットテスト
// importFromClipboard() の正常系・異常系を検証する。

import 'package:ashita_motsumono/src/services/text_import_service.dart';
import 'package:ashita_motsumono/src/utils/text_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextImportService.importFromClipboard', () {
    test('空文字の場合はTextImportEmptyを通知する', () async {
      final service = TextImportService(learnedItemLabels: const []);

      try {
        final resultFuture = service.onImport.first;

        await service.importFromClipboard('   ');

        final result = await resultFuture;
        expect(result, isA<TextImportEmpty>());
        expect(
          (result as TextImportEmpty).source,
          ImportSource.clipboard,
        );
      } finally {
        service.dispose();
      }
    });

    test('nullの場合はTextImportEmptyを通知する', () async {
      final service = TextImportService(learnedItemLabels: const []);

      try {
        final resultFuture = service.onImport.first;

        await service.importFromClipboard(null);

        final result = await resultFuture;
        expect(result, isA<TextImportEmpty>());
        expect(
          (result as TextImportEmpty).source,
          ImportSource.clipboard,
        );
      } finally {
        service.dispose();
      }
    });

    test('正常なテキストの場合はTextImportSuccessを通知する', () async {
      final service = TextImportService(
        learnedItemLabels: const ['体操着'],
      );
      const input = '  明日\n持ち物：体操着  ';
      const expectedRawText = '明日\n持ち物：体操着';

      try {
        final resultFuture = service.onImport.first;

        await service.importFromClipboard(input);

        final result = await resultFuture;
        expect(result, isA<TextImportSuccess>());

        final success = result as TextImportSuccess;
        expect(success.source, ImportSource.clipboard);
        expect(success.rawText, expectedRawText);
        expect(success.drafts, isNotEmpty);
        expect(
          success.fingerprint,
          TextFingerprint.calculate(expectedRawText),
        );
      } finally {
        service.dispose();
      }
    });

    test('dispose後のインポートはStateErrorになる', () async {
      final service = TextImportService(learnedItemLabels: const []);

      final streamDone = expectLater(service.onImport, emitsDone);
      service.dispose();

      await streamDone;
      await expectLater(
        service.importFromClipboard(null),
        throwsA(isA<StateError>()),
      );
    });
  });
}
