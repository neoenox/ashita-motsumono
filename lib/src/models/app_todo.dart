import 'package:flutter/foundation.dart';

import 'checklist_item.dart';
import 'enums.dart';

@immutable
class AppTodo {
  const AppTodo({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.personId,
    this.documentId,
    this.dueDate,
    this.amount,
    this.note,
    this.notifyPreviousNight = true,
    this.notifySameMorning = true,
  });

  final String id;
  final String title;
  final String? personId;
  final String? documentId;
  final DateTime? dueDate;
  final TodoCategory category;
  final int? amount;
  final String? note;
  final TodoStatus status;
  final List<ChecklistItem> items;
  final bool notifyPreviousNight;
  final bool notifySameMorning;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDone => status == TodoStatus.done;

  AppTodo copyWith({
    String? id,
    String? title,
    String? personId,
    String? documentId,
    DateTime? dueDate,
    TodoCategory? category,
    int? amount,
    String? note,
    TodoStatus? status,
    List<ChecklistItem>? items,
    bool? notifyPreviousNight,
    bool? notifySameMorning,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearPersonId = false,
    bool clearDocumentId = false,
    bool clearDueDate = false,
    bool clearAmount = false,
    bool clearNote = false,
  }) {
    return AppTodo(
      id: id ?? this.id,
      title: title ?? this.title,
      personId: clearPersonId ? null : personId ?? this.personId,
      documentId: clearDocumentId ? null : documentId ?? this.documentId,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      category: category ?? this.category,
      amount: clearAmount ? null : amount ?? this.amount,
      note: clearNote ? null : note ?? this.note,
      status: status ?? this.status,
      items: items ?? this.items,
      notifyPreviousNight: notifyPreviousNight ?? this.notifyPreviousNight,
      notifySameMorning: notifySameMorning ?? this.notifySameMorning,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'personId': personId,
        'documentId': documentId,
        'dueDate': dueDate?.toIso8601String(),
        'category': category.name,
        'amount': amount,
        'note': note,
        'status': status.name,
        'items': items.map((item) => item.toJson()).toList(),
        'notifyPreviousNight': notifyPreviousNight,
        'notifySameMorning': notifySameMorning,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AppTodo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final categoryName = json['category'];
    final statusName = json['status'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final rawItems = json['items'];
    final previousNight = json['notifyPreviousNight'];
    final sameMorning = json['notifySameMorning'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('AppTodo.id is invalid');
    }
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('AppTodo.title is invalid');
    }
    final category = TodoCategory.values
        .where((value) => value.name == categoryName)
        .firstOrNull;
    final status = TodoStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;
    if (category == null || status == null) {
      throw const FormatException('AppTodo enum value is invalid');
    }
    if (createdAt == null || updatedAt == null || rawItems is! List) {
      throw const FormatException('AppTodo fields are invalid');
    }
    if (previousNight is! bool || sameMorning is! bool) {
      throw const FormatException('AppTodo notification flags are invalid');
    }

    final dueDateRaw = json['dueDate'];
    final dueDate = dueDateRaw == null
        ? null
        : DateTime.tryParse(dueDateRaw as String? ?? '');
    if (dueDateRaw != null && dueDate == null) {
      throw const FormatException('AppTodo.dueDate is invalid');
    }

    return AppTodo(
      id: id,
      title: title,
      personId: json['personId'] as String? ?? json['childId'] as String?,
      documentId: json['documentId'] as String?,
      dueDate: dueDate,
      category: category,
      amount: json['amount'] as int?,
      note: json['note'] as String?,
      status: status,
      items: rawItems
          .map(
            (value) => ChecklistItem.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList(),
      notifyPreviousNight: previousNight,
      notifySameMorning: sameMorning,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
