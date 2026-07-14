// lib/src/screens/widgets/child_dropdown.dart
// 人物選択のドロップダウン。Todo追加・レビュー画面で共通利用。
// 関連: add_todo_screen.dart, review_extraction_screen.dart

import 'package:flutter/material.dart';

import '../../models/entities.dart';

class ChildDropdown extends StatelessWidget {
  const ChildDropdown({
    super.key,
    required this.value,
    required this.children,
    required this.onChanged,
  });

  final String? value;
  final List<PersonProfile> children;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: const InputDecoration(labelText: '対象', hintText: '未指定'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('未指定')),
        ...children.map(
          (child) => DropdownMenuItem<String?>(
            value: child.id,
            child: Text(child.name),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
