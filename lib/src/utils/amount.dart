// lib/src/utils/amount.dart
// 金額文字列をパースするユーティリティ。カンマ除去、空文字対応。
// 関連: utils/string_utils.dart, screens/add_todo_screen.dart,
//       screens/todo_detail_screen.dart, screens/review_extraction_screen.dart

({bool valid, int? amount}) parseAmount(String value) {
  final text = value.replaceAll(',', '').trim();
  if (text.isEmpty) return (valid: true, amount: null);
  final amount = int.tryParse(text);
  if (amount == null) return (valid: false, amount: null);
  return (valid: true, amount: amount);
}
