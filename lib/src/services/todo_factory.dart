// lib/src/services/todo_factory.dart
// ExtractionDraftからAppTodoを生成する責務をAppStateから分離する。

import 'package:uuid/uuid.dart';

import '../models/entities.dart';

class TodoFactory {
  TodoFactory(this._uuid);

  final Uuid _uuid;

  AppTodo fromDraft({
    required ExtractionDraft draft,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return AppTodo(
      id: _uuid.v4(),
      title: draft.title.trim().isEmpty ? 'プリントを確認' : draft.title.trim(),
      personId: personId,
      documentId: documentId,
      dueDate: draft.dueDate,
      category: draft.category,
      amount: draft.amount,
      note: draft.note,
      status: TodoStatus.active,
      items: draft.items
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .map((label) => ChecklistItem(id: _uuid.v4(), label: label))
          .toList(),
      notifyPreviousNight: notifyPreviousNight,
      notifySameMorning: notifySameMorning,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  List<AppTodo> fromDrafts({
    required Iterable<ExtractionDraft> drafts,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return drafts
        .map(
          (draft) => fromDraft(
            draft: draft,
            personId: personId,
            documentId: documentId,
            notifyPreviousNight: notifyPreviousNight,
            notifySameMorning: notifySameMorning,
            now: timestamp,
          ),
        )
        .toList();
  }
}
