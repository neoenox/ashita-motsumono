// lib/src/screens/preparation_screen.dart
// 「今日の準備」モード画面。期限が本日以前のTodoを1件ずつ表示し、
// 準備確認・あとで・今回除外の操作を提供する。完了画面で安心感を与える。
// 関連: screens/home_screen.dart, app_state.dart, theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../theme/app_theme.dart';

/// 「今日の準備」モード画面
///
/// 外部から独立して起動できる:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => PreparationScreen(date: DateTime.now()),
///   ),
/// );
/// ```
class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key, required this.date});

  final DateTime date;

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

/// 画面のフェーズ
enum _Phase { normal, complete }

/// 1件の準備項目
class _PrepItem {
  _PrepItem({required this.todo, required this.person});
  final AppTodo todo;
  final PersonProfile? person;
}

class _PreparationScreenState extends State<PreparationScreen> {
  List<_PrepItem> _allItems = [];
  int _currentIndex = 0;
  final Set<String> _deferredTodoIds = {};
  final Set<String> _excludedTodoIds = {};
  final Set<String> _preparedTodoIds = {};
  bool _inDeferredPass = false;
  int _completedCount = 0;
  _Phase _phase = _Phase.normal;

  List<_PrepItem> get _visibleItems {
    return _allItems.where((item) {
      final id = item.todo.id;
      if (_excludedTodoIds.contains(id)) return false;
      if (_preparedTodoIds.contains(id)) return false;
      if (_inDeferredPass) return _deferredTodoIds.contains(id);
      return !_deferredTodoIds.contains(id);
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allItems.isEmpty) {
      _loadItems();
    }
  }

  void _loadItems() {
    final state = context.read<AppState>();
    final todos = state.todosForPreparation(widget.date);
    _allItems = todos.map((todo) {
      final person = todo.personId != null
          ? state.personById(todo.personId)
          : null;
      return _PrepItem(todo: todo, person: person);
    }).toList();
  }

  void _advanceOrComplete() {
    if (_currentIndex >= _visibleItems.length) {
      if (!_inDeferredPass && _deferredTodoIds.isNotEmpty) {
        setState(() {
          _inDeferredPass = true;
          _currentIndex = 0;
        });
      } else {
        setState(() => _phase = _Phase.complete);
      }
    } else {
      setState(() {});
    }
  }

  Future<void> _markPrepared(String todoId) async {
    final state = context.read<AppState>();
    await state.markTodoPrepared(todoId, widget.date);
  }

  Future<void> _clearPrepared(String todoId) async {
    final state = context.read<AppState>();
    await state.clearTodoPrepared(todoId);
  }

  void _onPrepared(String todoId) {
    if (_preparedTodoIds.contains(todoId)) return;
    _preparedTodoIds.add(todoId);
    _completedCount++;
    // 非同期で永続化（画面操作を止めない）
    _markPrepared(todoId);
    final todo = _allItems.firstWhere((i) => i.todo.id == todoId).todo;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text('「${todo.title}」を準備済みにしました'),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () {
            _preparedTodoIds.remove(todoId);
            _completedCount--;
            // 可能なら現在位置の直後に再挿入、実装が複雑なら末尾へ
            _clearPrepared(todoId);
            setState(() {});
          },
        ),
      ),
    );
    _advanceOrComplete();
  }

  void _onDefer(String todoId) {
    _deferredTodoIds.add(todoId);
    _advanceOrComplete();
  }

  void _onExclude(String todoId) {
    if (_excludedTodoIds.contains(todoId)) return;
    _excludedTodoIds.add(todoId);
    final todo = _allItems.firstWhere((i) => i.todo.id == todoId).todo;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('「${todo.title}」を今回は外しました'),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () {
            _excludedTodoIds.remove(todoId);
            setState(() {});
          },
        ),
      ),
    );
    _advanceOrComplete();
  }

  void _onCancel() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('準備を中断しますか？'),
        content: const Text(
          '準備済みにした項目は保存されています。\n'
          '未確認の項目は次回も表示されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('中断する'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.complete) {
      return _buildCompletionScreen();
    }
    final items = _visibleItems;
    if (_currentIndex >= items.length && items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _advanceOrComplete());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (items.isEmpty) {
      // すでに全件準備済み、または準備対象なし
      if (_completedCount == 0) {
        final preparedCount =
            context.read<AppState>().todosPreparedToday(widget.date).length;
        return _buildAlreadyDoneScreen(preparedCount);
      }
      return _buildCompletionScreen();
    }
    final item = items[_currentIndex];
    return _buildItemScreen(item, items.length);
  }

  Widget _buildItemScreen(_PrepItem item, int total) {
    final todo = item.todo;
    final person = item.person;
    final current = _currentIndex + 1;
    final isDeferredPass = _inDeferredPass;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onCancel,
        ),
        title: Text(
          isDeferredPass ? 'あとで確認' : '今日の準備',
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'exclude') _onExclude(todo.id);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'exclude',
                child: ListTile(
                  leading: Icon(Icons.remove_circle_outline),
                  title: Text('今回は外す'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isDeferredPass)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Text(
                'あとでにした項目をもう一度確認します',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontSize: 13,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  '$current / $total',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? current / total : 0,
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md, Spacing.sm, Spacing.md, Spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (person != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(person.colorValue),
                          child: Text(
                            person.name.isNotEmpty
                                ? person.name.characters.first
                                : '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          person.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                avatar: Icon(
                                  _categoryIcon(todo.category),
                                  size: 16,
                                  color: todo.category.color,
                                ),
                                label: Text(
                                  todo.category.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: todo.category.color,
                                  ),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              const Spacer(),
                              if (todo.dueDate != null)
                                Text(
                                  _formatDate(todo.dueDate!),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            todo.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (todo.amount != null) ...[
                            const SizedBox(height: Spacing.sm),
                            Text(
                              '${todo.amount}円',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                          if (todo.items.isNotEmpty) ...[
                            const SizedBox(height: Spacing.md),
                            const Divider(),
                            const SizedBox(height: Spacing.sm),
                            ...todo.items.map((item) => CheckboxListTile(
                                  value: item.isChecked,
                                  onChanged: (_) {
                                    context
                                        .read<AppState>()
                                        .toggleItem(todo.id, item.id);
                                  },
                                  title: Text(
                                    item.label,
                                    style: TextStyle(
                                      decoration: item.isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.isChecked
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                          : null,
                                    ),
                                  ),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                )),
                          ],
                          if (todo.note != null &&
                              todo.note!.isNotEmpty) ...[
                            const SizedBox(height: Spacing.sm),
                            const Divider(),
                            const SizedBox(height: Spacing.sm),
                            Text(
                              todo.note!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md, 0, Spacing.md, Spacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _onPrepared(todo.id),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('準備できた'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (!isDeferredPass) ...[
                    const SizedBox(height: Spacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _onDefer(todo.id),
                        icon: const Icon(Icons.access_time),
                        label: const Text('あとで'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyDoneScreen(int preparedCount) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('今日の準備'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                '今日の準備は完了です',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                preparedCount > 0
                    ? '$preparedCount件準備できました'
                    : '今日は準備が必要な項目はありません',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ホームに戻る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final allDone = _deferredTodoIds
        .every((id) => _preparedTodoIds.contains(id) || _excludedTodoIds.contains(id));
    final unresolved = _deferredTodoIds
        .where((id) =>
            !_preparedTodoIds.contains(id) && !_excludedTodoIds.contains(id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('今日の準備'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                allDone ? Icons.check_circle : Icons.info_outline,
                size: 64,
                color: allDone
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                allDone ? '今日の準備は完了です' : '準備できていないものが${unresolved.length}件あります',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                allDone
                    ? '$_completedCount件すべて確認しました'
                    : '$_completedCount件準備できました',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (!allDone && unresolved.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                const Divider(),
                const SizedBox(height: Spacing.sm),
                ...unresolved.map((id) {
                  final item = _allItems.firstWhere((i) => i.todo.id == id);
                  final person = item.person;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Row(
                      children: [
                        if (person != null) ...[
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: Color(person.colorValue),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: Spacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            item.todo.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: Spacing.lg),
              if (!allDone)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _phase = _Phase.normal;
                        _inDeferredPass = true;
                        _currentIndex = 0;
                      });
                    },
                    child: const Text('未確認を続ける'),
                  ),
                ),
              const SizedBox(height: Spacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ホームに戻る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(TodoCategory category) {
    return switch (category) {
      TodoCategory.item => Icons.shopping_bag_outlined,
      TodoCategory.submit => Icons.mail_outline,
      TodoCategory.payment => Icons.account_balance_wallet_outlined,
      TodoCategory.event => Icons.event_outlined,
      TodoCategory.other => Icons.assignment_outlined,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
