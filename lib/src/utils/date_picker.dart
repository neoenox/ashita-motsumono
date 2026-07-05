// lib/src/utils/date_picker.dart
// 期限選択のDatePickerを共通化。
// 関連: screens/add_todo_screen.dart, screens/todo_detail_screen.dart,
//       screens/review_extraction_screen.dart

import 'package:flutter/material.dart';

Future<DateTime?> pickDueDate(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final result = await showDatePicker(
    context: context,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 3),
    initialDate: initial ?? now,
  );
  return result;
}
