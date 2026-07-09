// lib/src/utils/text_normalizer.dart
// OCR テキストの正規化処理。全角→半角変換、OCR誤認識補正、空白整理。
// 関連: extraction_service.dart

class TextNormalizer {
  TextNormalizer._();

  static final _multiSpacePattern = RegExp(r'[ \t]+');
  static final _multiNewlinePattern = RegExp(r'\n{3,}');

  static String normalize(String input) {
    final sb = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      // 全角数字 (FF10-FF19) を半角 (30-39) に変換
      if (codeUnit >= 0xFF10 && codeUnit <= 0xFF19) {
        sb.writeCharCode(codeUnit - 0xFF10 + 0x30);
      } else {
        sb.writeCharCode(codeUnit);
      }
    }
    var text = sb
        .toString()
        .replaceAll('／', '/')
        .replaceAll('，', ',')
        .replaceAll('￥', '¥')
        .replaceAll('　', ' ')
        .replaceAll(_multiSpacePattern, ' ')
        .replaceAll(_multiNewlinePattern, '\n\n')
        .trim();
    text = text.replaceAllMapped(RegExp(r'(?<=\d)[ー一](?=\d)'), (_) => '/');
    text = text.replaceAllMapped(RegExp(r'円\s*(?=\d)'), (_) => '¥');
    // OCR誤認識: 数字に隣接するO/l、またはlO/Ol連鎖を0/1に変換
    // lO→10 / Ol→01 のペアは1回のreplaceAllMappedで変換（先読みだけでは不十分）
    text = text.replaceAllMapped(
      RegExp(r'lO|Ol|(?<=\d)[Ol]|[Ol](?=\d)'),
      (m) => switch (m[0]) {
        'lO' => '10',
        'Ol' => '01',
        'O' => '0',
        _ => '1',
      },
    );
    return text;
  }
}
