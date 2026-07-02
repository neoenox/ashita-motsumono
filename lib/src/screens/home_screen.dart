// lib/src/screens/home_screen.dart
// ホーム画面。今日・明日・未設定・今後のTodoをセクション分けして表示。
// FABからTodo追加、AppBarから子ども管理画面へ遷移。
// 関連: screens/add_todo_screen.dart, screens/add_child_screen.dart,
//       screens/todo_detail_screen.dart, app_state.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../utils/date_formatters.dart';
import 'add_child_screen.dart';
import 'add_todo_screen.dart';
import 'todo_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final todayTodos = state.todosForDate(today);
    final tomorrowTodos = state.todosForDate(tomorrow);
    final undated = state.undatedTodos();

    return Scaffold(
      appBar: AppBar(
        title: const Text('あした持つもの'),
        actions: [
          IconButton(
            tooltip: '子どもを追加',
            icon: const Icon(Icons.child_care),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddChildScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (state.children.isEmpty) const _FirstRunCard(),
          _TodoSection(title: '今日やること', todos: todayTodos),
          const SizedBox(height: 16),
          _TodoSection(title: '明日の持ち物・提出', todos: tomorrowTodos),
          const SizedBox(height: 16),
          _TodoSection(title: '期限未設定・要確認', todos: undated),
          const SizedBox(height: 16),
          _UpcomingSection(todos: state.upcomingTodos()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTodoScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}

class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('まず子どもを登録', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Todoは子ども別に整理できます。MVPではログインなし・端末内保存です。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddChildScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('子どもを追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoSection extends StatelessWidget {
  const _TodoSection({required this.title, required this.todos});

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
              const Text('なし')
            else
              ...todos.map((todo) => _TodoTile(todo: todo)),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.todos});

  final List<AppTodo> todos;

  @override
  Widget build(BuildContext context) {
    final future = todos
        .where((todo) => todo.dueDate != null && todo.dueDate!.isAfter(DateTime.now().add(const Duration(days: 1))))
        .take(10)
        .toList();
    if (future.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今後の予定', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...future.map((todo) => _TodoTile(todo: todo, compact: true)),
          ],
        ),
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.todo, this.compact = false});

  final AppTodo todo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final child = state.childById(todo.childId);
    final subtitle = [
      todo.category.label,
      formatDueDate(todo.dueDate),
      if (child != null) child.name,
      if (todo.amount != null) '${todo.amount}円',
    ].join(' / ');

    return ListTile(
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
    );
  }
}
