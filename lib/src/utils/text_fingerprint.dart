// lib/src/utils/text_fingerprint.dart
// テキストの正規化とSHA-256ハッシュ生成
// なぜ存在するか: 共有メニューからのテキスト重複判定に使用
// 関連文件: extraction_service.dart, text_import_service.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';

class TextFingerprint {
  const TextFingerprint._();

  /// テキストを正規化する（空白・改行統一）
  static String normalize(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// SHA-256ハッシュを計算する
  static String calculate(String input) {
    final normalized = normalize(input);
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}