// lib/src/utils/string_utils.dart
// 文字列操作の共通ユーティリティ。持ち物リストの分割など。
// 関連: utils/amount.dart, screens/add_todo_screen.dart,
//       screens/todo_detail_screen.dart, screens/review_extraction_screen.dart

List<String> splitItems(String input) => input
    .split(RegExp(r'[,、\n]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();
