// lib/src/screens/widgets/todo_section.dart
// 今日やること・明日の提出などのTodoセクションと、今後の予定セクション。
// 関連: home_screen.dart, widgets/todo_tile.dart, theme/app_theme.dart

import 'package:flutter/material.dart';

import '../../models/entities.dart';
import '../../theme/app_theme.dart';
import 'todo_tile.dart';

class TodoSection extends StatelessWidget {
  const TodoSection({super.key, required this.title, required this.todos});

  final String title;
  final List<AppTodo> todos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            if (todos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: Spacing.sm),
                    Text('すべて完了',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              )
            else
              ...todos.map((todo) => TodoTile(todo: todo)),
          ],
        ),
      ),
    );
  }
}

class UpcomingSection extends StatelessWidget {
  const UpcomingSection({super.key, required this.todos});

  final List<AppTodo> todos;

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final shown = todos.take(10).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今後の予定',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            ...shown.map((todo) => TodoTile(todo: todo, compact: true)),
            if (todos.length > 10) ...[
              const SizedBox(height: Spacing.sm),
              Text('他 ${todos.length - 10} 件',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
