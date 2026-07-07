// lib/src/screens/widgets/todo_section.dart
// 今日やること・明日の提出などのTodoセクションと、今後の予定セクション。
// 関連: home_screen.dart, widgets/todo_tile.dart

import 'package:flutter/material.dart';

import '../../models/entities.dart';
import 'todo_tile.dart';

class TodoSection extends StatelessWidget {
  const TodoSection({super.key, required this.title, required this.todos});

  final String title;
  final List<AppTodo> todos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (todos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text('すべて完了', style: TextStyle(color: Colors.grey[500])),
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
    final shown = todos.take(10).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今後の予定', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...shown.map((todo) => TodoTile(todo: todo, compact: true)),
            if (todos.length > 10) ...[
              const SizedBox(height: 8),
              Text('他 ${todos.length - 10} 件',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
