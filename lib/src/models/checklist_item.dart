// lib/src/models/checklist_item.dart
// Todoに紐づくチェックリスト項目（ID、ラベル、チェック状態）を保持するモデル。
// AppTodo.items で使うリスト要素。toJson/fromJson で永続化可能。
// 関連: entities.dart, app_todo.dart

import 'package:flutter/foundation.dart';

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
    id: (json['id'] as String?) ?? '',
    label: (json['label'] as String?) ?? '',
    isChecked: json['isChecked'] as bool? ?? false,
  );
}
