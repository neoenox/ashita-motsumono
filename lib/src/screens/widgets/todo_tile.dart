// lib/src/screens/widgets/todo_tile.dart
// Todo 1件を表示する。詳細画面の状態依存は画面Scopeへ委譲する。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_navigation.dart';
import '../../app_state.dart';
import '../../models/entities.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatters.dart';
import '../todo_detail_screen_scope.dart';

class TodoTile extends StatefulWidget {
  const TodoTile({super.key, required this.todo, this.compact = false});

  final AppTodo todo;
  final bool compact;

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile> {
  bool _pressed = false;

  AppTodo get todo => widget.todo;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final child = appState.personById(todo.personId);
    final subtitle = [
      todo.category.label,
      formatDueDate(todo.dueDate),
      if (child != null) child.name,
      if (todo.amount != null) '${todo.amount}円',
    ].join(' / ');
    final reducedMotion = context.isReducedMotion;
    final bandColor = todo.isDone
        ? CategoryColors.completed
        : todo.category.color;

    final tile = InkWell(
      onHighlightChanged: _setPressed,
      onTap: () => pushAdaptive<void>(
        context,
        (_) => TodoDetailScreenScope(todoId: todo.id),
      ),
      child: AnimatedOpacity(
        duration: reducedMotion ? AppMotion.quick : AppMotion.standard,
        curve: AppMotion.standardCurve,
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
                _AnimatedTodoCheckbox(
                  value: todo.isDone,
                  reducedMotion: reducedMotion,
                  onChanged: () {
                    HapticFeedback.selectionClick();
                    appState.toggleTodoDone(todo.id);
                  },
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
                          maxLines: widget.compact ? 1 : 2,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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

    final pressableTile = reducedMotion
        ? tile
        : AnimatedScale(
            duration: AppMotion.quick,
            curve: AppMotion.standardCurve,
            scale: _pressed ? 0.98 : 1,
            child: tile,
          );

    return Dismissible(
      key: ValueKey('todo-${todo.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      movementDuration: AppMotion.standard,
      background: const _SwipeBackground(
        color: Colors.green,
        icon: Icons.check_circle_outline,
        label: '完了',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: Theme.of(context).colorScheme.error,
        icon: Icons.delete_outline,
        label: '削除',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) => _confirmDismiss(direction, appState),
      child: pressableTile,
    );
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  Future<bool> _confirmDismiss(
    DismissDirection direction,
    AppState appState,
  ) async {
    if (direction == DismissDirection.startToEnd) {
      await HapticFeedback.lightImpact();
      await appState.toggleTodoDone(todo.id);
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Todoを削除'),
        content: Text('「${todo.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    await HapticFeedback.lightImpact();
    await appState.deleteTodo(todo.id);
    return false;
  }
}

class _AnimatedTodoCheckbox extends StatelessWidget {
  const _AnimatedTodoCheckbox({
    required this.value,
    required this.reducedMotion,
    required this.onChanged,
  });

  final bool value;
  final bool reducedMotion;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // Checkbox自体を残し、既存のSemanticsとテスト契約を維持する。
    return AnimatedScale(
      duration: reducedMotion ? Duration.zero : AppMotion.standard,
      curve: AppMotion.standardCurve,
      scale: value ? 1 : 0.92,
      child: Checkbox(
        value: value,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isStart = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isStart) Text(label, style: _labelStyle),
          if (!isStart) const SizedBox(width: Spacing.sm),
          Icon(icon, color: Colors.white),
          if (isStart) const SizedBox(width: Spacing.sm),
          if (isStart) Text(label, style: _labelStyle),
        ],
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
  );
}
