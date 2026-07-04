// lib/src/models/entities.dart
// アプリ全体で使うドメインモデル（ChildProfile, AppTodo, ChecklistItem, DocumentRecord, ExtractionDraft, AppSnapshot）。
// すべて @immutable で toJson/fromJson を持ち、SharedPreferences に保存できる。
// 関連: repositories/store.dart, app_state.dart

import 'package:flutter/foundation.dart';

@immutable
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChildProfile copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['colorValue'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

enum TodoCategory {
  item,
  submit,
  payment,
  event,
  other;

  String get label => switch (this) {
        TodoCategory.item => '持ち物',
        TodoCategory.submit => '提出',
        TodoCategory.payment => '集金',
        TodoCategory.event => '予定',
        TodoCategory.other => 'その他',
      };

  static TodoCategory fromName(String? value) {
    return TodoCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TodoCategory.other,
    );
  }
}

enum TodoStatus {
  active,
  done,
  archived;

  static TodoStatus fromName(String? value) {
    return TodoStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TodoStatus.active,
    );
  }
}

@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.label,
    this.isChecked = false,
  });

  final String id;
  final String label;
  final bool isChecked;

  ChecklistItem copyWith({String? id, String? label, bool? isChecked}) {
    return ChecklistItem(
      id: id ?? this.id,
      label: label ?? this.label,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'isChecked': isChecked,
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        label: json['label'] as String,
        isChecked: json['isChecked'] as bool? ?? false,
      );
}

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
    this.childId,
    this.documentId,
    this.dueDate,
    this.amount,
    this.note,
    this.notifyPreviousNight = true,
    this.notifySameMorning = true,
  });

  final String id;
  final String title;
  final String? childId;
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
    String? childId,
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
    bool clearChildId = false,
    bool clearDocumentId = false,
    bool clearDueDate = false,
    bool clearAmount = false,
    bool clearNote = false,
  }) {
    return AppTodo(
      id: id ?? this.id,
      title: title ?? this.title,
      childId: clearChildId ? null : childId ?? this.childId,
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
        'childId': childId,
        'documentId': documentId,
        'dueDate': dueDate?.toIso8601String(),
        'category': category.name,
        'amount': amount,
        'note': note,
        'status': status.name,
        'items': items.map((e) => e.toJson()).toList(),
        'notifyPreviousNight': notifyPreviousNight,
        'notifySameMorning': notifySameMorning,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AppTodo.fromJson(Map<String, dynamic> json) => AppTodo(
        id: json['id'] as String,
        title: json['title'] as String,
        childId: json['childId'] as String?,
        documentId: json['documentId'] as String?,
        dueDate: (json['dueDate'] as String?) == null
            ? null
            : DateTime.parse(json['dueDate'] as String),
        category: TodoCategory.fromName(json['category'] as String?),
        amount: json['amount'] as int?,
        note: json['note'] as String?,
        status: TodoStatus.fromName(json['status'] as String?),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        notifyPreviousNight: json['notifyPreviousNight'] as bool? ?? true,
        notifySameMorning: json['notifySameMorning'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

@immutable
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.localImagePath,
    this.ocrText,
  });

  final String id;
  final String sourceType;
  final String? localImagePath;
  final String? ocrText;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceType': sourceType,
        'localImagePath': localImagePath,
        'ocrText': ocrText,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DocumentRecord.fromJson(Map<String, dynamic> json) => DocumentRecord(
        id: json['id'] as String,
        sourceType: json['sourceType'] as String,
        localImagePath: json['localImagePath'] as String?,
        ocrText: json['ocrText'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

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

@immutable
class AppSnapshot {
  const AppSnapshot({
    required this.children,
    required this.todos,
    required this.documents,
    this.version = currentVersion,
  });

  final List<ChildProfile> children;
  final List<AppTodo> todos;
  final List<DocumentRecord> documents;
  final int version;

  static const currentVersion = 1;
  static const empty = AppSnapshot(children: [], todos: [], documents: []);

  AppSnapshot migrate() {
    var migrated = this;
    if (version < 1) {
      // v0→v1: どのTodoからも参照されていない孤立ドキュメントを削除
      final activeDocIds = migrated.todos
          .map((t) => t.documentId)
          .whereType<String>()
          .toSet();
      migrated = AppSnapshot(
        children: migrated.children,
        todos: migrated.todos,
        documents: migrated.documents.where((d) => activeDocIds.contains(d.id)).toList(),
        version: 1,
      );
    }
    return migrated;
  }

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'children': children.map((e) => e.toJson()).toList(),
        'todos': todos.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
      };

  factory AppSnapshot.fromJson(Map<String, dynamic> json) => AppSnapshot(
        version: json['version'] as int? ?? 0,
        children: (json['children'] as List<dynamic>? ?? const [])
            .map((e) => ChildProfile.fromJson(e as Map<String, dynamic>))
            .toList(),
        todos: (json['todos'] as List<dynamic>? ?? const [])
            .map((e) => AppTodo.fromJson(e as Map<String, dynamic>))
            .toList(),
        documents: (json['documents'] as List<dynamic>? ?? const [])
            .map((e) => DocumentRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
