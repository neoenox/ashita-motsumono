// test/extraction_service_test.dart
// ExtractionService の抽出ロジックを網羅的にテストする。
// 日付・金額・持ち物・カテゴリ・タイトル生成の各ケースを検証。
// 関連: lib/src/services/extraction_service.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/services/extraction_service.dart';

void main() {
  final now = DateTime(2026, 7, 2);

  group('ExtractionService.extract', () {
    test('extracts date, items and payment from Japanese print text', () {
      final draft = ExtractionService().extract(
        '7月10日までに水着、帽子、タオルを持参してください。\n集金袋に500円を入れて提出してください。',
        now: now,
      );
      expect(draft.dueDate, DateTime(2026, 7, 10));
      expect(draft.amount, 500);
      expect(draft.items, containsAll(['水着', '帽子', 'タオル', '集金袋']));
      expect(draft.category, TodoCategory.payment);
    });

    test('rolls month/day date to next year when already past', () {
      final draft = ExtractionService().extract('1月10日 体操着を持参', now: now);
      expect(draft.dueDate, DateTime(2027, 1, 10));
    });

    test('normalizes full-width digits', () {
      final draft = ExtractionService().extract('７月１０日までに￥５００を提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
      expect(draft.amount, 500);
    });

    test('extracts date with slash format', () {
      final draft = ExtractionService().extract('7/10までに水着を持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test('extracts date with full year format', () {
      final draft = ExtractionService().extract('2026年8月15日までに申込書を提出', now: now);
      expect(draft.dueDate, DateTime(2026, 8, 15));
    });

    test('recognizes "明日" as tomorrow', () {
      final draft = ExtractionService().extract('明日までにタオルを持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 3));
    });

    test('recognizes "今日" as today', () {
      final draft = ExtractionService().extract('今日中に提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 2));
    });

    test('returns null date when no date found', () {
      final draft = ExtractionService().extract('水筒とタオルを持参してください', now: now);
      expect(draft.dueDate, isNull);
    });

    test('extracts amount with yen sign', () {
      final draft = ExtractionService().extract('¥1,500を集金します', now: now);
      expect(draft.amount, 1500);
    });

    test('extracts amount with comma', () {
      final draft = ExtractionService().extract('集金3,000円', now: now);
      expect(draft.amount, 3000);
    });

    test('extracts amount without comma', () {
      final draft = ExtractionService().extract('500円を提出', now: now);
      expect(draft.amount, 500);
    });

    test('returns null amount when no amount found', () {
      final draft = ExtractionService().extract('水筒を持参してください', now: now);
      expect(draft.amount, isNull);
    });

    test('infers category as payment when amount present', () {
      final draft = ExtractionService().extract('集金 800円', now: now);
      expect(draft.category, TodoCategory.payment);
    });

    test('infers category as submit from keywords', () {
      final draft = ExtractionService().extract('提出物があります。返信してください。', now: now);
      expect(draft.category, TodoCategory.submit);
    });

    test('infers category as event from keywords', () {
      final draft = ExtractionService().extract('遠足の案内。面談の日程。', now: now);
      expect(draft.category, TodoCategory.event);
    });

    test('infers category as item when items found', () {
      final draft = ExtractionService().extract('水筒とタオルを持参', now: now);
      expect(draft.category, TodoCategory.item);
    });

    test('infers category as other when nothing matches', () {
      final draft = ExtractionService().extract('本日は通常通りです。', now: now);
      expect(draft.category, TodoCategory.other);
    });

    test('generates title for payment with amount', () {
      final draft = ExtractionService().extract('¥500を集金します', now: now);
      expect(draft.title, '集金 500円');
    });

    test('generates title for submit item', () {
      final draft = ExtractionService().extract('申込書を提出してください', now: now);
      expect(draft.title, '申込書を提出');
    });

    test('generates title from first line when category is other', () {
      final draft = ExtractionService().extract('来週の予定について\n\n通常授業です。', now: now);
      expect(draft.title, '来週の予定について');
    });

    test('generates fallback title when text is empty', () {
      final draft = ExtractionService().extract('', now: now);
      expect(draft.title, 'プリントを確認');
    });

    test('truncates rawText longer than 500 chars', () {
      final longText = '水筒 ' * 200;
      final draft = ExtractionService().extract(longText, now: now);
      expect(draft.note!.length, 503); // 500 + '...'
      expect(draft.note, endsWith('...'));
    });

    test('extracts items from dictionary', () {
      final draft = ExtractionService().extract('水筒、上履き、体操着、マスク', now: now);
      expect(draft.items, containsAll(['水筒', '上履き', '体操着', 'マスク']));
    });

    test('returns empty items when nothing matches', () {
      final draft = ExtractionService().extract('キャンプファイヤー、花火', now: now);
      expect(draft.items, isEmpty);
    });
  });

  group('ExtractionService.normalize', () {
    test('converts full-width digits to half-width', () {
      expect(ExtractionService().normalize('７月１０日'), '7月10日');
    });

    test('normalizes slashes and yen signs', () {
      expect(ExtractionService().normalize('￥１，０００'), '¥1,000');
    });

    test('collapses multiple spaces', () {
      expect(ExtractionService().normalize('水筒  持参'), '水筒 持参');
    });

    test('collapses excessive newlines', () {
      expect(ExtractionService().normalize('水筒\n\n\n持参'), '水筒\n\n持参');
    });

    test('trims whitespace', () {
      expect(ExtractionService().normalize('  水筒  '), '水筒');
    });
  });
}
