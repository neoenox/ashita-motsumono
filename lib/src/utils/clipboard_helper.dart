// lib/src/utils/clipboard_helper.dart
// クリップボードからテキストを読み取るユーティリティ
// なぜ存在するか: add_todo_screen.dart に services.dart を直接importすると
//   テスト4件が落ちるため、クリップボード操作を分離する
// 関連: add_todo_screen.dart

import 'package:flutter/services.dart';

/// クリップボードからテキストを取得する
Future<String?> getClipboardText() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  return data?.text;
}
