// lib/src/screens/widgets/todo_tile.dart
// Todo 1件を表示する。カテゴリ色帯＋リストアイテム。
// Stitch デザインに合わせてスタイル調整。
// 関連: home_screen.dart, todo_section.dart, theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/entities.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatters.dart';
import '../todo_detail_screen.dart';

class TodoTile extends StatelessWidget {
  const TodoTile({super.key, required this.todo, this.compact = false});

  final AppTodo todo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = context.select<AppState, PersonProfile?>(
      (s) => s.personById(todo.personId),
    );
    final subtitle = [
      todo.category.label,
      formatDueDate(todo.dueDate),
      if (child != null) child.name,
      if (todo.amount != null) '${todo.amount}円',
    ].join(' / ');

    final bandColor = todo.isDone
        ? CategoryColors.completed
        : todo.category.color;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TodoDetailScreen(todoId: todo.id),
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: todo.isDone ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: bandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: Spacing.sm),
              Checkbox(
                value: todo.isDone,
                onChanged: (_) =>
                    context.read<AppState>().toggleTodoDone(todo.id),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
