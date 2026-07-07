// lib/src/screens/widgets/filter_bar.dart
// 完了済みフィルターと人物フィルターを横に並べたバー。
// 関連: home_screen.dart, widgets/todo_tile.dart

import 'package:flutter/material.dart';

import '../../models/entities.dart';
import '../../theme/app_theme.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.showCompleted,
    required this.filterPersonId,
    required this.children,
    required this.onToggleCompleted,
    required this.onChangeChild,
  });

  final bool showCompleted;
  final String? filterPersonId;
  final List<PersonProfile> children;
  final ValueChanged<bool> onToggleCompleted;
  final ValueChanged<String?> onChangeChild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      child: Row(
        children: [
          FilterChip(
            label: const Text('完了済み'),
            selected: showCompleted,
            onSelected: onToggleCompleted,
          ),
          const SizedBox(width: Spacing.sm),
          if (children.length > 1)
            DropdownButton<String?>(
              value: filterPersonId,
              hint: const Text('すべて'),
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('すべて')),
                ...children.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: onChangeChild,
            ),
          if (filterPersonId != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => onChangeChild(null),
              tooltip: 'フィルター解除',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
