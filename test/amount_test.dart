// test/amount_test.dart
// parseAmount のパースロジックをテストする。
// 関連: lib/src/utils/amount.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/utils/amount.dart';

void main() {
  group('parseAmount', () {
    test('parses plain number', () {
      final r = parseAmount('500');
      expect(r.valid, isTrue);
      expect(r.amount, 500);
    });

    test('parses number with commas', () {
      final r = parseAmount('1,500');
      expect(r.valid, isTrue);
      expect(r.amount, 1500);
    });

    test('returns null amount for empty string', () {
      final r = parseAmount('');
      expect(r.valid, isTrue);
      expect(r.amount, isNull);
    });

    test('returns null amount for whitespace', () {
      final r = parseAmount('  ');
      expect(r.valid, isTrue);
      expect(r.amount, isNull);
    });

    test('returns invalid for non-numeric', () {
      final r = parseAmount('abc');
      expect(r.valid, isFalse);
      expect(r.amount, isNull);
    });

    test('parses amount with 円 suffix', () {
      final r = parseAmount('500円');
      expect(r.valid, isTrue);
      expect(r.amount, 500);
    });

    test('parses amount with ¥ prefix and comma', () {
      final r = parseAmount('¥1,200');
      expect(r.valid, isTrue);
      expect(r.amount, 1200);
    });
  });
}
