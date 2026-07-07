// lib/src/models/todo_update.dart
// Todo更新用の値オブジェクト。copyWith のパラメータ数を減らすために使う。
// 関連: app_todo.dart

import 'package:flutter/foundation.dart';
import 'enums.dart';
import 'checklist_item.dart';

@immutable
class TodoUpdate {
  const TodoUpdate({
    this.title,
    this.personId,
    this.documentId,
    this.dueDate,
    this.category,
    this.amount,
    this.note,
    this.status,
    this.items,
    this.notifyPreviousNight,
    this.notifySameMorning,
    this.clearPersonId = false,
    this.clearDocumentId = false,
    this.clearDueDate = false,
    this.clearAmount = false,
    this.clearNote = false,
  });

  final String? title;
  final String? personId;
  final String? documentId;
  final DateTime? dueDate;
  final TodoCategory? category;
  final int? amount;
  final String? note;
  final TodoStatus? status;
  final List<ChecklistItem>? items;
  final bool? notifyPreviousNight;
  final bool? notifySameMorning;
  final bool clearPersonId;
  final bool clearDocumentId;
  final bool clearDueDate;
  final bool clearAmount;
  final bool clearNote;

  bool get hasChanges =>
      title != null ||
      personId != null ||
      documentId != null ||
      dueDate != null ||
      category != null ||
      amount != null ||
      note != null ||
      status != null ||
      items != null ||
      notifyPreviousNight != null ||
      notifySameMorning != null ||
      clearPersonId ||
      clearDocumentId ||
      clearDueDate ||
      clearAmount ||
      clearNote;
}
