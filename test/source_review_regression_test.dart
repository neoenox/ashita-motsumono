import 'dart:io';

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/date_extractor.dart';
import 'package:ashita_motsumono/src/services/sensitive_data_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('date extraction regressions', () {
    test('deadline date wins over distribution date', () {
      final result = DateExtractor.extract(
        '本日配布しました。提出期限は2026年8月10日です。',
        DateTime(2026, 8, 5),
      );

      expect(result, DateTime(2026, 8, 10));
    });

    test('strong deadline language wins over an earlier action word', () {
      final result = DateExtractor.extract(
        '提出物を本日配布しました。期限は8月10日です。',
        DateTime(2026, 8, 5),
      );

      expect(result, DateTime(2026, 8, 10));
    });

    test('nearest deadline date wins when multiple concrete dates exist', () {
      final result = DateExtractor.extract(
        '2026年8月5日に配布しました。提出期限は8月10日です。',
        DateTime(2026, 8, 5),
      );

      expect(result, DateTime(2026, 8, 10));
    });

    test('submit language selects its adjacent date', () {
      final result = DateExtractor.extract(
        '8月5日に配布しました。8月10日に提出してください。',
        DateTime(2026, 8, 5),
      );

      expect(result, DateTime(2026, 8, 10));
    });

    test(
      'date immediately before made deadline wins over distribution date',
      () {
        final result = DateExtractor.extract(
          '8月5日配布、8月10日までに提出してください。',
          DateTime(2026, 8, 5),
        );

        expect(result, DateTime(2026, 8, 10));
      },
    );

    test('class notation is not treated as a slash date', () {
      final result = DateExtractor.extract(
        '1-2組は水筒を持参してください。',
        DateTime(2026, 8, 5),
      );

      expect(result, isNull);
    });

    test('deadline-relative date wins over earlier distribution date', () {
      final result = DateExtractor.extract(
        '本日配布しました。提出は明日までです。',
        DateTime(2026, 8, 5),
      );

      expect(result, DateTime(2026, 8, 6));
    });
  });

  test('new learned labels are retained at the 100 item cap', () async {
    SharedPreferences.setMockInitialValues({
      'learned_item_labels_v1': [
        for (var index = 0; index < 100; index++) '既存$index',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);

    await settings.addLearnedItemLabels(const ['新しい持ち物']);

    expect(settings.learnedItemLabels, hasLength(100));
    expect(settings.learnedItemLabels.first, '新しい持ち物');
    expect(settings.learnedItemLabels, isNot(contains('既存99')));
  });

  test('corrupt database sidecar backups are removed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ashita_sensitive_cleanup_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final removable = [
      'ashita_motsumono_corrupt_test.db',
      'ashita_motsumono_corrupt_test.db-wal',
      'ashita_motsumono_corrupt_test.db-shm',
      'ashita_motsumono_corrupt_test.db-journal',
    ];
    for (final name in removable) {
      await File('${directory.path}/$name').writeAsString(name);
    }
    final unrelated = File('${directory.path}/keep.txt');
    await unrelated.writeAsString('keep');

    final cleaner = SensitiveDataCleaner(
      directoryProvider: () async => directory,
    );
    await cleaner.clearResidualFiles();

    for (final name in removable) {
      expect(await File('${directory.path}/$name').exists(), isFalse);
    }
    expect(await unrelated.exists(), isTrue);
  });

  test('post-delete cleanup is limited to captured todo ids', () {
    final source = File('lib/src/app_state_cleanup.dart').readAsStringSync();

    expect(source, contains('executeCanceledTodo(todoId)'));
    expect(source, contains('_runPostDeleteCleanup(todoIdsToCancel)'));
    expect(source, isNot(contains('retryPending(const <AppTodo>[])')));
  });

  test('platform plugins are guarded by runtime platform checks', () {
    final home = File('lib/src/screens/home_screen.dart').readAsStringSync();
    final scope = File(
      'lib/src/screens/home_screen_scope.dart',
    ).readAsStringSync();

    expect(home, contains('Platform.isAndroid || Platform.isIOS'));
    expect(scope, contains('!Platform.isAndroid'));
    expect(scope, isNot(contains('defaultTargetPlatform')));
  });
}
