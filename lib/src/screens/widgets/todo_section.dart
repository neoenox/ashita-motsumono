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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: Spacing.sm),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            child: todos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Spacing.md,
                      horizontal: Spacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          'すべて完了',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: todos.length,
                    itemBuilder: (context, index) =>
                        TodoTile(todo: todos[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

class UpcomingSection extends StatefulWidget {
  const UpcomingSection({super.key, required this.todos});

  final List<AppTodo> todos;

  @override
  State<UpcomingSection> createState() => _UpcomingSectionState();
}

class _UpcomingSectionState extends State<UpcomingSection> {
  static const _collapsedLimit = 10;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final todos = widget.todos;
    if (todos.isEmpty) return const SizedBox.shrink();
    final overflowCount = todos.length - _collapsedLimit;
    final shown = _expanded ? todos : todos.take(_collapsedLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: Spacing.sm),
          child: Text(
            '今後の予定',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            child: Column(
              children: [
                ...shown.map((todo) => TodoTile(todo: todo, compact: true)),
                if (overflowCount > 0) ...[
                  const SizedBox(height: Spacing.sm),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xs,
                        vertical: Spacing.xs,
                      ),
                      child: Text(
                        _expanded ? '閉じる' : '他 $overflowCount 件',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
