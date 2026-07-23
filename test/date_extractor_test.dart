// test/date_extractor_test.dart
// DateExtractor の日付抽出ロジックを単体テストする。
// 相対日付・曜日指定・具体日・スラッシュ日付の各ケースを網羅。
// 関連: lib/src/services/date_extractor.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/services/date_extractor.dart';

void main() {
  final now = DateTime(2026, 7, 2); // 木曜日

  group('DateExtractor.extract', () {
    test('extracts full date with year', () {
      expect(DateExtractor.extract('2026年7月10日まで', now), DateTime(2026, 7, 10));
    });

    test('extracts month/day date', () {
      expect(DateExtractor.extract('7月10日まで', now), DateTime(2026, 7, 10));
    });

    test('extracts slash date', () {
      expect(DateExtractor.extract('7/10まで', now), DateTime(2026, 7, 10));
    });

    test('recognizes "明日" as tomorrow', () {
      expect(DateExtractor.extract('明日まで', now), DateTime(2026, 7, 3));
    });

    test('recognizes "今日" as today', () {
      expect(DateExtractor.extract('今日中', now), DateTime(2026, 7, 2));
    });

    test('recognizes "明後日" as day after tomorrow', () {
      expect(DateExtractor.extract('明後日まで', now), DateTime(2026, 7, 4));
    });

    test('recognizes "翌日" as next day', () {
      expect(DateExtractor.extract('翌日以降', now), DateTime(2026, 7, 3));
    });

    test('returns null for past month/day date instead of rolling', () {
      final pastNow = DateTime(2026, 12, 15);
      expect(DateExtractor.extract('1月10日まで', pastNow), isNull);
    });

    test('subtracts one day for "前日まで" with concrete date', () {
      expect(DateExtractor.extract('7月10日前日まで', now), DateTime(2026, 7, 9));
    });

    test('recognizes next week weekday', () {
      // now = 2026/7/2 (Thu), 来週の金曜 = 2026/7/10
      expect(DateExtractor.extract('来週の金曜日', now), DateTime(2026, 7, 10));
    });

    test('recognizes this week weekday', () {
      // now = 2026/7/2 (Thu), 今週の金曜 = 2026/7/3
      expect(DateExtractor.extract('今週の金曜日', now), DateTime(2026, 7, 3));
    });

    test('recognizes next weekday expression on the same weekday', () {
      // now = 2026/7/2 (Thu), 次の木曜 = 2026/7/9
      expect(DateExtractor.extract('次の木曜日', now), DateTime(2026, 7, 9));
    });

    test('returns null when no date found', () {
      expect(DateExtractor.extract('タオルを持参', now), isNull);
    });

    test('returns null for "来週" without weekday', () {
      expect(DateExtractor.extract('来週まで', now), isNull);
    });
  });

  group('DateExtractor.hasAmbiguousDeadline', () {
    test('returns true for "月末" with deadline context', () {
      expect(DateExtractor.hasAmbiguousDeadline('月末まで'), true);
    });

    test('returns false for "月末" without deadline context', () {
      expect(DateExtractor.hasAmbiguousDeadline('月末です'), false);
    });

    test('returns true for "始業式の日" with "持参"', () {
      expect(DateExtractor.hasAmbiguousDeadline('始業式の日持参'), true);
    });

    test('returns false for unrelated text', () {
      expect(DateExtractor.hasAmbiguousDeadline('今日はいい天気'), false);
    });
  });

  group('DateExtractor.hasPastMonthDayDate', () {
    test('returns true for past month/day date', () {
      final now = DateTime(2026, 7, 15);
      expect(DateExtractor.hasPastMonthDayDate('7月10日まで', now), true);
    });

    test('returns false for future month/day date', () {
      final now = DateTime(2026, 7, 5);
      expect(DateExtractor.hasPastMonthDayDate('7月10日まで', now), false);
    });

    test('returns true for past slash date', () {
      final now = DateTime(2026, 12, 15);
      expect(DateExtractor.hasPastMonthDayDate('1/10まで', now), true);
    });

    test('returns false when no month/day pattern found', () {
      expect(
        DateExtractor.hasPastMonthDayDate('タオルを持参', DateTime(2026, 7, 2)),
        false,
      );
    });

    test('matches month/day substring within full date', () {
      // 年ありの日付にも「7月10日」の部分文字列としてマッチする
      // 実際の抽出では _extractConcreteDate が先にマッチして dueDate が null にならないので
      // hasPastMonthDayDate は参照されない
      expect(
        DateExtractor.hasPastMonthDayDate(
          '2026年7月10日まで',
          DateTime(2026, 7, 15),
        ),
        true,
      );
    });
  });
}
