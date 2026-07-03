// lib/src/screens/home_screen.dart
// ホーム画面。今日・明日・未設定・今後のTodoをセクション分けして表示。
// FABからTodo追加、AppBarから子ども管理画面へ遷移。
// 初回起動時に通知説明ダイアログを表示。
// 関連: screens/add_todo_screen.dart, screens/add_child_screen.dart,
//       screens/todo_detail_screen.dart, app_state.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../utils/date_formatters.dart';
import 'add_child_screen.dart';
import 'add_todo_screen.dart';
import 'todo_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _notificationDialogShown = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchQueryRaw = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loaded = context.read<AppState>().loaded;
    if (loaded && !_notificationDialogShown) {
      _notificationDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationInfo();
      });
    }
  }

  void _showNotificationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知について'),
        content: const Text(
          '前日20:00と当日7:00にTodoのリマインド通知をお送りします。'
          '通知を許可してください。後で設定を変更することもできます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('わかりました'),
          ),
        ],
      ),
    );
  }

  void _exportData(AppState state) async {
    final json = const JsonEncoder.withIndent('  ').convert(
      AppSnapshot(children: state.children, todos: state.todos, documents: state.documents).toJson(),
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データをクリップボードにコピーしました')),
      );
    }
  }

  List<AppTodo> _filter(List<AppTodo> todos, List<ChildProfile> children) {
    if (_searchQuery.isEmpty) return todos;
    final q = _searchQuery.toLowerCase();
    return todos.where((t) {
      if (t.title.toLowerCase().contains(q)) return true;
      if (t.category.label.contains(q)) return true;
      if (t.note?.toLowerCase().contains(q) == true) return true;
      if (t.amount?.toString().contains(q) == true) return true;
      final child = children.where((c) => c.id == t.childId).firstOrNull;
      if (child?.name.toLowerCase().contains(q) == true) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final todayTodos = _filter(state.todosForDate(today), state.children);
    final tomorrowTodos = _filter(state.todosForDate(tomorrow), state.children);
    final undated = _filter(state.undatedTodos(), state.children);
    final allFiltered = todayTodos.isEmpty && tomorrowTodos.isEmpty && undated.isEmpty;

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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') _exportData(state);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export', child: ListTile(
                leading: Icon(Icons.download),
                title: Text('データをエクスポート'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '検索…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _searchQueryRaw = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() {
                _searchQueryRaw = v.trim();
                _searchQuery = v.trim().toLowerCase();
              }),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (state.children.isEmpty) const _FirstRunCard(),
                if (state.children.isNotEmpty && allFiltered && _searchQuery.isEmpty && state.todos.isEmpty)
                  _EmptyState(),
                if (state.children.isNotEmpty && allFiltered && _searchQuery.isNotEmpty)
                  _NoSearchResults(query: _searchQueryRaw),
                if (todayTodos.isNotEmpty || _searchQuery.isEmpty) ...[
                  _TodoSection(title: '今日やること', todos: todayTodos),
                  const SizedBox(height: 16),
                ],
                _TodoSection(title: '明日の持ち物・提出', todos: tomorrowTodos),
                const SizedBox(height: 16),
                _TodoSection(title: '期限未設定・要確認', todos: undated),
                const SizedBox(height: 16),
                _UpcomingSection(todos: state.upcomingTodos()),
              ],
            ),
          ),
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

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('「$query」に一致するTodoはありません', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Todoがありません', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('「追加」ボタンから新しくTodoを作成できます', style: TextStyle(color: Colors.grey[400])),
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
