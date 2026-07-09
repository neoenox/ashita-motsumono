// test/text_normalizer_test.dart
// TextNormalizer の正規化ロジックをテストする。
// 全角→半角変換、OCR誤認識補正、空白整理を網羅。
// 関連: lib/src/utils/text_normalizer.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/utils/text_normalizer.dart';

void main() {
  group('TextNormalizer.normalize', () {
    test('converts full-width digits to half-width', () {
      expect(TextNormalizer.normalize('２０２６年'), '2026年');
    });

    test('normalizes slashes, yen signs and full-width commas', () {
      expect(TextNormalizer.normalize('３／１'), '3/1');
      expect(TextNormalizer.normalize('￥５００'), '¥500');
      expect(TextNormalizer.normalize('１，２００'), '1,200');
    });

    test('does not replace Japanese long vowel marks', () {
      expect(TextNormalizer.normalize('ほうき'), 'ほうき');
      expect(TextNormalizer.normalize('タオル'), 'タオル');
    });

    test('corrects OCR misread O to 0 adjacent to digits', () {
      expect(TextNormalizer.normalize('2O26'), '2026');
      expect(TextNormalizer.normalize('O7'), '07');
      expect(TextNormalizer.normalize('1O月'), '10月');
    });

    test('corrects OCR misread l to 1 adjacent to digits', () {
      expect(TextNormalizer.normalize('2l26'), '2126');
      expect(TextNormalizer.normalize('l2'), '12');
      expect(TextNormalizer.normalize('1l月'), '11月');
    });

    test('corrects lO and Ol OCR artifacts', () {
      expect(TextNormalizer.normalize('lO'), '10');
      expect(TextNormalizer.normalize('Ol'), '01');
    });

    test('does not replace O or l in non-numeric context', () {
      expect(TextNormalizer.normalize('NOTE'), 'NOTE');
      expect(TextNormalizer.normalize('hello'), 'hello');
    });

    test('converts full-width spaces to half-width', () {
      expect(TextNormalizer.normalize('abc　def'), 'abc def');
    });

    test('collapses multiple spaces', () {
      expect(TextNormalizer.normalize('a   b    c'), 'a b c');
    });

    test('collapses excessive newlines', () {
      expect(TextNormalizer.normalize('a\n\n\n\nb'), 'a\n\nb');
    });

    test('trims whitespace', () {
      expect(TextNormalizer.normalize('  hello  '), 'hello');
    });

    test('replaces long vowel separator between digits with slash', () {
      expect(TextNormalizer.normalize('3ー1'), '3/1');
    });

    test('replaces kanji one separator between digits with slash', () {
      expect(TextNormalizer.normalize('3一1'), '3/1');
    });

    test('inverts yen mark before digits', () {
      expect(TextNormalizer.normalize('円500'), '¥500');
    });

    test('handles empty input', () {
      expect(TextNormalizer.normalize(''), '');
    });

    test('handles mixed full-width and half-width', () {
      expect(TextNormalizer.normalize('７月１０日（金）'), '7月10日（金）');
    });
  });
}
