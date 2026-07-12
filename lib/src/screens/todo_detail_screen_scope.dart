// lib/src/screens/todo_detail_screen_scope.dart
// Todo詳細が依存する人物・Todo・Document状態の購読を画面境界にカプセル化する。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_data_notifiers.dart';
import 'todo_detail_screen.dart';

class TodoDetailScreenScope extends StatelessWidget {
  const TodoDetailScreenScope({super.key, required this.todoId});

  final String todoId;

  @override
  Widget build(BuildContext context) {
    context.watch<ChildState>();
    context.watch<TodoState>();
    context.watch<DocumentState>();
    return TodoDetailScreen(todoId: todoId);
  }
}
