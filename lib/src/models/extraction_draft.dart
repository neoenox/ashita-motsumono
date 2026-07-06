// lib/src/models/extraction_draft.dart
// OCR抽出結果から生成されるTodo下書き。確定前に編集・確認するための一時モデル。
// AppTodo生成前の一時状態を扱うために存在する。
// 関連: entities.dart, enums.dart, app_todo.dart

import 'package:flutter/foundation.dart';
import 'enums.dart';

@immutable
class ExtractionDraft {
  const ExtractionDraft({
    required this.title,
    required this.category,
    required this.items,
    this.dueDate,
    this.amount,
    this.note,
    this.rawText,
  });

  final String title;
  final TodoCategory category;
  final DateTime? dueDate;
  final int? amount;
  final List<String> items;
  final String? note;
  final String? rawText;

  ExtractionDraft copyWith({
    String? title,
    TodoCategory? category,
    DateTime? dueDate,
    int? amount,
    List<String>? items,
    String? note,
    String? rawText,
    bool clearDueDate = false,
    bool clearAmount = false,
  }) {
    return ExtractionDraft(
      title: title ?? this.title,
      category: category ?? this.category,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      amount: clearAmount ? null : amount ?? this.amount,
      items: items ?? this.items,
      note: note ?? this.note,
      rawText: rawText ?? this.rawText,
    );
  }
}
