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

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    final checked = json['isChecked'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('ChecklistItem.id is invalid');
    }
    if (label is! String || label.trim().isEmpty) {
      throw const FormatException('ChecklistItem.label is invalid');
    }
    if (checked != null && checked is! bool) {
      throw const FormatException('ChecklistItem.isChecked is invalid');
    }
    return ChecklistItem(
      id: id,
      label: label,
      isChecked: checked as bool? ?? false,
    );
  }
}
