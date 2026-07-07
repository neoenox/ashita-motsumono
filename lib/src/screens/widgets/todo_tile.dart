// lib/src/screens/widgets/todo_tile.dart
// Todo 1件を表示する。カテゴリ色帯＋ListTile の組み合わせ。
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
    final child = context.select<AppState, PersonProfile?>((s) => s.personById(todo.personId));
    final subtitle = [
      todo.category.label,
      formatDueDate(todo.dueDate),
      if (child != null) child.name,
      if (todo.amount != null) '${todo.amount}円',
    ].join(' / ');

    final bandColor = todo.isDone
        ? CategoryColors.completed
        : CategoryColors.fromCategory(todo.category.name);

    final tile = IntrinsicHeight(
      child: Row(
        children: [
          Container(width: 4, color: bandColor),
          Expanded(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: todo.isDone,
                onChanged: (_) => context.read<AppState>().toggleTodoDone(todo.id),
              ),
              title: Text(
                todo.title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: todo.isDone
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TodoDetailScreen(todoId: todo.id)),
              ),
            ),
          ),
        ],
      ),
    );

    if (todo.isDone) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 0.6,
        child: tile,
      );
    }
    return tile;
  }
}
