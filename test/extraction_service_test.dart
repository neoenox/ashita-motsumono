// test/extraction_service_test.dart
// ExtractionService の抽出ロジックを網羅的にテストする。
// 日付・金額・持ち物・カテゴリ・タイトル生成の各ケースを検証。
// 関連: lib/src/services/extraction_service.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/services/extraction_service.dart';

void main() {
  final now = DateTime(2026, 7, 2);

  group('ExtractionService.extractMany', () {
    test('splits item, payment and submit notices into separate drafts', () {
      final drafts = ExtractionService.extractMany(
        '7月10日までに水着、帽子、タオルを持参してください。\n'
        '集金袋に500円を入れて提出してください。\n'
        '申込書は7月12日までに提出してください。',
        now: now,
      );

      expect(drafts, hasLength(3));
      expect(drafts.map((draft) => draft.category), [
        TodoCategory.item,
        TodoCategory.payment,
        TodoCategory.submit,
      ]);
      expect(drafts[0].title, '持ち物：水着・帽子・タオル');
      expect(drafts[0].items, ['水着', '帽子', 'タオル']);
      expect(drafts[0].dueDate, DateTime(2026, 7, 10));
      expect(drafts[1].title, '集金 500円');
      expect(drafts[1].amount, 500);
      expect(drafts[1].items, ['集金袋']);
      expect(drafts[2].title, '申込書を提出');
      expect(drafts[2].dueDate, DateTime(2026, 7, 12));
    });

    test('falls back to a single draft when no useful split is found', () {
      final drafts = ExtractionService.extractMany('7月10日までに水筒を持参', now: now);

      expect(drafts, hasLength(1));
      expect(drafts.single.title, '持ち物：水筒');
    });

    test('uses learned item labels as extraction candidates', () {
      final drafts = ExtractionService.extractMany(
        '7月10日までに軍手を持参',
        now: now,
        learnedItemLabels: ['軍手'],
      );

      expect(drafts.single.items, ['軍手']);
      expect(drafts.single.title, '持ち物：軍手');
    });

    test('returns empty list for non-actionable text', () {
      final drafts = ExtractionService.extractMany(
        'これはテストです。特に何も書いていません。',
        now: now,
      );
      expect(drafts, isEmpty);
    });
  });

  group('ExtractionService.extract', () {
    test('extracts date, items and payment from Japanese print text', () {
      final draft = ExtractionService.extract(
        '7月10日までに水着、帽子、タオルを持参してください。\n集金袋に500円を入れて提出してください。',
        now: now,
      );
      expect(draft.dueDate, DateTime(2026, 7, 10));
      expect(draft.amount, 500);
      expect(draft.items, containsAll(['水着', '帽子', 'タオル', '集金袋']));
      expect(draft.category, TodoCategory.payment);
    });

    test('returns null dueDate for past month/day date and flags confirmation', () {
      final draft = ExtractionService.extract('1月10日 体操着を持参', now: now);
      expect(draft.dueDate, isNull);
      expect(draft.title, contains('期限確認'));
    });

    test('normalizes full-width digits', () {
      final draft = ExtractionService.extract('７月１０日までに￥５００を提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
      expect(draft.amount, 500);
    });

    test('normalizes O/l only adjacent to digits, not in English words', () {
      final draft = ExtractionService.extract(
        '1O月1O日 Hello World を持参 l0枚 O型 2O25',
        now: now,
      );
      // '1O' → '10', 'l0' → '10', '2O25' → '2025'
      expect(draft.dueDate, DateTime(2026, 10, 10));
      expect(draft.note, contains('Hello World'));
      expect(draft.note, contains('O型'));
    });

    test('extracts date with slash format', () {
      final draft = ExtractionService.extract('7/10までに水着を持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test('extracts date with full year format', () {
      final draft = ExtractionService.extract('2026年8月15日までに申込書を提出', now: now);
      expect(draft.dueDate, DateTime(2026, 8, 15));
    });

    test('recognizes "明日" as tomorrow', () {
      final draft = ExtractionService.extract('明日までにタオルを持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 3));
    });

    test('recognizes "今日" as today', () {
      final draft = ExtractionService.extract('今日中に提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 2));
    });

    test('recognizes next week weekday expressions', () {
      final draft = ExtractionService.extract('来週月曜までに水泳カードを提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 6));
    });

    test('recognizes this week weekday expressions', () {
      final draft = ExtractionService.extract('今週金曜日までに雑巾を持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 3));
    });

    test('recognizes next weekday expression on the same weekday', () {
      final draft = ExtractionService.extract('次の木曜までに提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 9));
    });

    test('"来週" without weekday yields null (not yet supported)', () {
      final draft = ExtractionService.extract(
        '来週までに提出',
        now: DateTime(2026, 7, 7),
      );
      // current impl requires weekday after "来週", e.g. 来週月曜
      expect(draft.dueDate, isNull);
    });

    test('recognizes "明後日" as day after tomorrow', () {
      final draft = ExtractionService.extract('明後日までに水筒を持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 4));
    });

    test('recognizes "翌日" as next day', () {
      final draft = ExtractionService.extract('翌日までに申込書を提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 3));
    });

    test('subtracts one day for "前日まで" with concrete date', () {
      final draft = ExtractionService.extract('7月10日 前日までに提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 9));
    });

    test('subtracts one day for "前日まで" with slash date', () {
      final draft = ExtractionService.extract('7/10の前日までに申込書を提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 9));
    });

    test('extracts date with weekday in parentheses (半角)', () {
      final draft = ExtractionService.extract('7月10日(火)までに水着を持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test('extracts date with weekday in full-width parentheses', () {
      final draft = ExtractionService.extract('7/10（火）までにタオルを持参', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test('extracts slash date with weekday in parentheses', () {
      final draft = ExtractionService.extract('7/10(火)までに申込書を提出', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test('returns null when no date found with "前日まで"', () {
      final draft = ExtractionService.extract('運動会の前日までにタオルを持参', now: now);
      expect(draft.dueDate, isNull);
    });

    test('returns null for ambiguous date "今月末"', () {
      final draft = ExtractionService.extract('今月末までに申込書を提出', now: now);
      expect(draft.dueDate, isNull);
      expect(draft.title, '期限確認：申込書を提出');
    });

    test('marks ambiguous "月末" deadline as confirmation needed', () {
      final draft = ExtractionService.extract('月末までに集金袋へ800円を入れて提出', now: now);
      expect(draft.dueDate, isNull);
      expect(draft.title, '期限確認：集金 800円');
    });

    test('returns null for ambiguous date "始業式の日"', () {
      final draft = ExtractionService.extract('始業式の日までに筆記用具を持参', now: now);
      expect(draft.dueDate, isNull);
      expect(draft.title, '期限確認：持ち物：筆記用具');
    });

    test('returns null date when no date found', () {
      final draft = ExtractionService.extract('水筒とタオルを持参してください', now: now);
      expect(draft.dueDate, isNull);
    });

    test('extracts amount with yen sign', () {
      final draft = ExtractionService.extract('¥1,500を集金します', now: now);
      expect(draft.amount, 1500);
    });

    test('extracts amount with comma', () {
      final draft = ExtractionService.extract('集金3,000円', now: now);
      expect(draft.amount, 3000);
    });

    test('extracts amount without comma', () {
      final draft = ExtractionService.extract('500円を提出', now: now);
      expect(draft.amount, 500);
    });

    test('returns null amount when no amount found', () {
      final draft = ExtractionService.extract('水筒を持参してください', now: now);
      expect(draft.amount, isNull);
    });

    test('infers category as payment when amount present', () {
      final draft = ExtractionService.extract('集金 800円', now: now);
      expect(draft.category, TodoCategory.payment);
    });

    test('infers category as submit from keywords', () {
      final draft = ExtractionService.extract('提出物があります。返信してください。', now: now);
      expect(draft.category, TodoCategory.submit);
    });

    test('infers category as event from keywords', () {
      final draft = ExtractionService.extract('遠足の案内。面談の日程。', now: now);
      expect(draft.category, TodoCategory.event);
    });

    test('infers category as item when items found', () {
      final draft = ExtractionService.extract('水筒とタオルを持参', now: now);
      expect(draft.category, TodoCategory.item);
    });

    test('infers category as other when nothing matches', () {
      final draft = ExtractionService.extract('本日は通常通りです。', now: now);
      expect(draft.category, TodoCategory.other);
    });

    test('generates title for payment with amount', () {
      final draft = ExtractionService.extract('¥500を集金します', now: now);
      expect(draft.title, '集金 500円');
    });

    test('generates title for submit item', () {
      final draft = ExtractionService.extract('申込書を提出してください', now: now);
      expect(draft.title, '申込書を提出');
    });

    test('generates title from first line when category is other', () {
      final draft = ExtractionService.extract('来週の予定について\n\n通常授業です。', now: now);
      expect(draft.title, '来週の予定について');
    });

    test('generates fallback title when text is empty', () {
      final draft = ExtractionService.extract('', now: now);
      expect(draft.title, 'プリントを確認');
    });

    test('truncates rawText longer than 500 chars', () {
      final longText = '水筒 ' * 200;
      final draft = ExtractionService.extract(longText, now: now);
      expect(draft.note!.length, 503); // 500 + '...'
      expect(draft.note, endsWith('...'));
    });

    test('extracts items from dictionary', () {
      final draft = ExtractionService.extract('水筒、上履き、体操着、マスク', now: now);
      expect(draft.items, containsAll(['水筒', '上履き', '体操着', 'マスク']));
    });

    test('extracts expanded school item dictionary', () {
      final draft = ExtractionService.extract(
        '水泳カード、検温表、雑巾、エプロン、三角巾、鍵盤ハーモニカ',
        now: now,
      );
      expect(
        draft.items,
        containsAll(['水泳カード', '検温表', '雑巾', 'エプロン', '三角巾', '鍵盤ハーモニカ']),
      );
    });

    test('keeps long vowel marks in item names', () {
      final draft = ExtractionService.extract('プールバッグとレジャーシートを持参', now: now);
      expect(draft.items, containsAll(['プールバッグ', 'レジャーシート']));
    });

    test('does not duplicate shorter item contained in longer item', () {
      final draft = ExtractionService.extract('バスタオルとお弁当を持参', now: now);
      expect(draft.items, containsAll(['バスタオル', 'お弁当']));
      expect(draft.items, isNot(contains('タオル')));
      expect(draft.items, isNot(contains('弁当')));
    });

    test('returns empty items when nothing matches', () {
      final draft = ExtractionService.extract('キャンプファイヤー、花火', now: now);
      expect(draft.items, isEmpty);
    });

    test('extracts integer part from decimal amount', () {
      final draft = ExtractionService.extract('¥1,500.50 を集金', now: now);
      // current impl parses the integer part before the decimal
      expect(draft.amount, 1500);
    });

    test('recognizes "午前中" as time context (no date extractable)', () {
      final draft = ExtractionService.extract('午前中にタオルを持参', now: now);
      expect(draft.dueDate, isNull);
    });

    test('recognizes "締切" near date', () {
      final draft = ExtractionService.extract('7月10日締切', now: now);
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test('extracts items in text order', () {
      final draft = ExtractionService.extract('帽子と水筒とタオルを持参', now: now);
      expect(draft.items, orderedEquals(['帽子', '水筒', 'タオル']));
    });
  });

  group('ExtractionService.normalize', () {
    test('converts full-width digits to half-width', () {
      expect(ExtractionService.normalize('７月１０日'), '7月10日');
    });

    test('normalizes slashes, yen signs and full-width commas', () {
      expect(ExtractionService.normalize('￥１，０００'), '¥1,000');
    });

    test('does not replace Japanese long vowel marks', () {
      expect(ExtractionService.normalize('プールバッグ'), 'プールバッグ');
    });

    test('corrects OCR misread O→0 in date', () {
      expect(ExtractionService.normalize('1O月O5日'), '10月05日');
    });

    test('corrects OCR misread l→1 in date', () {
      expect(ExtractionService.normalize('7月l0日'), '7月10日');
    });

    test('extracts date after OCR correction O→0', () {
      final draft = ExtractionService.extract(
        '1O月O5日までに提出',
        now: DateTime(2026, 7, 2),
      );
      expect(draft.dueDate, DateTime(2026, 10, 5));
    });

    test('extracts date after OCR correction l→1', () {
      final draft = ExtractionService.extract(
        '7月l0日までに水着を持参',
        now: DateTime(2026, 7, 2),
      );
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test('extracts slash date after OCR correction', () {
      final draft = ExtractionService.extract(
        '7/lOまでに提出',
        now: DateTime(2026, 7, 2),
      );
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test(
      'extracts date after OCR correction for long vowel date separator',
      () {
        final draft = ExtractionService.extract(
          '7ー10までに水筒を持参',
          now: DateTime(2026, 7, 2),
        );
        expect(draft.dueDate, DateTime(2026, 7, 10));
      },
    );

    test('extracts date after OCR correction for kanji one date separator', () {
      final draft = ExtractionService.extract(
        '7一10までに申込書を提出',
        now: DateTime(2026, 7, 2),
      );
      expect(draft.dueDate, DateTime(2026, 7, 10));
    });

    test(
      'extracts amount after OCR correction for yen mark read as 円 prefix',
      () {
        final draft = ExtractionService.extract('円500を集金します', now: now);
        expect(draft.amount, 500);
        expect(draft.title, '集金 500円');
      },
    );

    test('collapses multiple spaces', () {
      expect(ExtractionService.normalize('水筒  持参'), '水筒 持参');
    });

    test('collapses excessive newlines', () {
      expect(ExtractionService.normalize('水筒\n\n\n持参'), '水筒\n\n持参');
    });

    test('converts full-width spaces to half-width', () {
      expect(ExtractionService.normalize('水筒　持参'), '水筒 持参');
    });

    test('trims whitespace', () {
      expect(ExtractionService.normalize('  水筒  '), '水筒');
    });
  });
}
