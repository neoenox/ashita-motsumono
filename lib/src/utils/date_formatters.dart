// lib/src/utils/date_formatters.dart
// intl パッケージを使った日付フォーマットのユーティリティ。
// 画面表示用。同一年なら M/d、異年なら yyyy/M/d と切り替える。
// 関連: screens/home_screen.dart, screens/todo_detail_screen.dart

import 'package:intl/intl.dart';

final _ymd = DateFormat('yyyy/MM/dd');
final _md = DateFormat('M/d');
final _hm = DateFormat('HH:mm');

String formatDueDate(DateTime? value) {
  if (value == null) return '期限なし';
  final now = DateTime.now();
  if (value.year == now.year) return _md.format(value);
  return _ymd.format(value);
}

String formatDateTime(DateTime value) => '${_ymd.format(value)} ${_hm.format(value)}';

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
