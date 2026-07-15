// test/item_extractor_nested_labels_test.dart
// ItemExtractor の包含語重複除去が、別位置の必須項目を落とさないことを検証する。

import 'package:ashita_motsumono/src/services/item_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemExtractor nested labels', () {
    test('preserves 上履き and 上履き袋 when both are listed separately', () {
      final items = ItemExtractor.extract('上履きと上履き袋を持参してください', const []);

      expect(items, orderedEquals(['上履き', '上履き袋']));
    });

    test('preserves learned 集金 label when separate from 集金袋', () {
      final items = ItemExtractor.extract(
        '集金と集金袋を確認してください',
        const ['集金'],
      );

      expect(items, orderedEquals(['集金', '集金袋']));
    });

    test('preserves learned 水泳 label when separate from 水泳カード', () {
      final items = ItemExtractor.extract(
        '水泳カードと水泳の予定を確認してください',
        const ['水泳'],
      );

      expect(items, orderedEquals(['水泳カード', '水泳']));
    });

    test('suppresses shorter labels that occur only inside longer items', () {
      final items = ItemExtractor.extract('バスタオルとお弁当を持参してください', const []);

      expect(items, orderedEquals(['バスタオル', 'お弁当']));
      expect(items, isNot(contains('タオル')));
      expect(items, isNot(contains('弁当')));
    });

    test('suppresses 上履き when it appears only as part of 上履き袋', () {
      final items = ItemExtractor.extract('上履き袋を持参してください', const []);

      expect(items, orderedEquals(['上履き袋']));
    });
  });
}
