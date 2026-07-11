// lib/src/models/app_todo.dart
// Todo本体（タイトル、カテゴリ、ステータス、チェックリスト、締切、通知設定、準備日）。
// アプリの中心的なドメインモデル。toJson/fromJson で永続化可能。
// 関連: entities.dart, enums.dart, checklist_item.dart, app_snapshot.dart

import 'package:flutter/foundation.dart';
import 'enums.dart';
import 'checklist_item.dart';

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
    this.preparedDate,
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
  final DateTime? preparedDate;

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
    DateTime? preparedDate,
    bool clearPersonId = false,
    bool clearDocumentId = false,
    bool clearDueDate = false,
    bool clearAmount = false,
    bool clearNote = false,
    bool clearPreparedDate = false,
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
      preparedDate: clearPreparedDate ? null : preparedDate ?? this.preparedDate,
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
        'items': items.map((e) => e.toJson()).toList(),
        'notifyPreviousNight': notifyPreviousNight,
        'notifySameMorning': notifySameMorning,
        'preparedDate': preparedDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AppTodo.fromJson(Map<String, dynamic> json) => AppTodo(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        personId: json['personId'] as String? ?? json['childId'] as String?,
        documentId: json['documentId'] as String?,
        dueDate: (json['dueDate'] as String?) != null
            ? DateTime.tryParse(json['dueDate'] as String)
            : null,
        category: TodoCategory.fromName(json['category'] as String?),
        amount: json['amount'] as int?,
        note: json['note'] as String?,
        status: TodoStatus.fromName(json['status'] as String?),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        notifyPreviousNight: json['notifyPreviousNight'] as bool? ?? true,
        notifySameMorning: json['notifySameMorning'] as bool? ?? true,
        preparedDate: (json['preparedDate'] as String?) != null
            ? DateTime.tryParse(json['preparedDate'] as String)
            : null,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
