// lib/src/screens/todo_detail_screen.dart
// Todo 詳細画面。タイトル・種類・期限・対象・金額・チェック項目・元画像を表示。
// 完了/未完了の切り替えと削除が可能。存在しないTodoの場合はエラー表示。
// 関連: screens/home_screen.dart, app_state.dart, utils/date_formatters.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../utils/date_formatters.dart';

class TodoDetailScreen extends StatelessWidget {
  const TodoDetailScreen({super.key, required this.todoId});

  final String todoId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final todo = state.todos.where((e) => e.id == todoId).firstOrNull;
    if (todo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Todo詳細')),
        body: const Center(child: Text('Todoが見つかりませんでした')),
      );
    }
    final child = state.childById(todo.childId);
    final document = state.documentById(todo.documentId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await context.read<AppState>().deleteTodo(todo.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(todo.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('種類：${todo.category.label}'),
                  Text('期限：${formatDueDate(todo.dueDate)}'),
                  if (child != null) Text('対象：${child.name}'),
                  if (todo.amount != null) Text('金額：${todo.amount}円'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.read<AppState>().toggleTodoDone(todo.id),
                    icon: Icon(todo.isDone ? Icons.undo : Icons.check),
                    label: Text(todo.isDone ? '未完了に戻す' : '完了にする'),
                  ),
                ],
              ),
            ),
          ),
          if (todo.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('チェック項目', style: Theme.of(context).textTheme.titleMedium),
                    ...todo.items.map(
                      (item) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: item.isChecked,
                        title: Text(item.label),
                        onChanged: (_) => context.read<AppState>().toggleItem(todo.id, item.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (todo.note != null && todo.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('メモ・OCR全文', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SelectableText(todo.note!),
                  ],
                ),
              ),
            ),
          ],
          if (document?.localImagePath != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('元画像', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(document!.localImagePath!)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
