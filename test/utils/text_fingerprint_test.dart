// test/utils/text_fingerprint_test.dart
//
// TextFingerprint のユニットテスト
// normalize() と calculate() の正常系・異常系を検証する。

import 'package:ashita_motsumono/src/utils/text_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextFingerprint.normalize', () {
    test('CRLFとCRをLFと同じ結果に正規化する', () {
      expect(
        TextFingerprint.normalize('1行目\r\n2行目\r3行目\n4行目'),
        '1行目 2行目 3行目 4行目',
      );
    });

    test('連続する空白文字を1つの空白に圧縮する', () {
      expect(
        TextFingerprint.normalize('明日   体操着\t\t水筒\n\nを持参'),
        '明日 体操着 水筒 を持参',
      );
    });

    test('先頭と末尾の空白を削除する', () {
      expect(TextFingerprint.normalize(' \t 明日は体操着を持参 \n '), '明日は体操着を持参');
    });

    test('空白を含まない日本語を変更しない', () {
      expect(TextFingerprint.normalize('明日は体操着を持参してください。'), '明日は体操着を持参してください。');
    });
  });

  group('TextFingerprint.calculate', () {
    test('同一内容から同一のハッシュを生成する', () {
      final first = TextFingerprint.calculate('明日  体操着を持参');
      final second = TextFingerprint.calculate('  明日 体操着を持参  ');

      expect(first, second);
    });

    test('空文字のSHA-256ハッシュを生成する', () {
      expect(
        TextFingerprint.calculate(''),
        'e3b0c44298fc1c149afbf4c8996fb924'
        '27ae41e4649b934ca495991b7852b855',
      );
    });

    test('日本語のSHA-256ハッシュを生成する', () {
      expect(
        TextFingerprint.calculate('明日は体操着'),
        '9b898e69e48342a36ed6ea0489cd0857'
        'c05e02084b2fff698672e8f4e6993575',
      );
    });
  });
}
