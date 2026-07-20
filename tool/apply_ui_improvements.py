from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')
    print(f'updated: {path}')


def replace_exact(path: str, old: str, new: str, *, expected: int = 1) -> None:
    content = read(path)
    actual = content.count(old)
    if actual != expected:
        raise RuntimeError(
            f'{path}: expected {expected} occurrence(s), found {actual}: {old[:120]!r}'
        )
    write(path, content.replace(old, new))


def insert_once(path: str, marker: str, addition: str) -> None:
    content = read(path)
    if addition in content:
        return
    if marker not in content:
        raise RuntimeError(f'{path}: insertion marker not found: {marker[:120]!r}')
    write(path, content.replace(marker, addition + marker, 1))


APP_NAVIGATION = """// lib/src/app_navigation.dart
// プラットフォームごとの標準操作感を保った画面遷移を提供する。

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 現在のプラットフォームに適したページルートを生成する。
///
/// [Navigator.pushReplacement] のスタック動作を維持する箇所でも同じ判定を
/// 再利用できるよう、ルート生成を分離している。
PageRoute<T> adaptivePageRoute<T>(
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return CupertinoPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
      );
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return MaterialPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
      );
  }
}

Future<T?> pushAdaptive<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  return Navigator.of(context).push<T>(
    adaptivePageRoute<T>(
      builder,
      fullscreenDialog: fullscreenDialog,
    ),
  );
}
"""


TODO_TILE = """// lib/src/screens/widgets/todo_tile.dart
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
      background: _SwipeBackground(
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
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      checked: value,
      label: value ? '未完了に戻す' : '完了にする',
      child: InkResponse(
        onTap: onChanged,
        radius: 24,
        child: AnimatedContainer(
          duration: reducedMotion ? Duration.zero : AppMotion.standard,
          curve: AppMotion.standardCurve,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? cs.primary : Colors.transparent,
            border: Border.all(
              color: value ? cs.primary : cs.outline,
              width: 2,
            ),
          ),
          child: value
              ? Icon(Icons.check, size: 22, color: cs.onPrimary)
              : null,
        ),
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
"""


def apply_app_theme() -> None:
    path = 'lib/src/theme/app_theme.dart'
    insert_once(
        path,
        'class AppTheme {',
        """class AppMotion {
  AppMotion._();

  static const quick = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 200);
  static const emphasized = Duration(milliseconds: 300);
  static const standardCurve = Curves.easeOutCubic;
  static const emphasizedCurve = Curves.fastOutSlowIn;
}

extension BuildContextMotion on BuildContext {
  /// OSの「アニメーションを減らす」設定を画面側で参照する。
  bool get isReducedMotion => MediaQuery.of(this).disableAnimations;
}

""",
    )
    replace_exact(
        path,
        """      fontFamily: 'NotoSansJP',
      appBarTheme: AppBarTheme(
""",
        """      fontFamily: 'NotoSansJP',
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
""",
    )


def apply_home_screen() -> None:
    path = 'lib/src/screens/home_screen.dart'
    replace_exact(
        path,
        "import '../app_state.dart';\n",
        "import '../app_navigation.dart';\nimport '../app_state.dart';\n",
    )
    replace_exact(
        path,
        """  bool _shareListenerInitialized = false;
""",
        """  bool _shareListenerInitialized = false;
  bool _fabPressed = false;
""",
    )
    replace_exact(
        path,
        """        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => reviewScreen,
          ),
        );
""",
        """        await pushAdaptive<void>(context, (_) => reviewScreen);
""",
    )
    replace_exact(
        path,
        """            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddChildScreen()),
            ),
""",
        """            onPressed: () => pushAdaptive<void>(
              context,
              (_) => const AddChildScreen(),
            ),
""",
    )
    replace_exact(
        path,
        """                    onAddPerson: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddChildScreen(),
                      ),
                    ),
""",
        """                    onAddPerson: () => pushAdaptive<void>(
                      context,
                      (_) => const AddChildScreen(),
                    ),
""",
    )
    replace_exact(
        path,
        """      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTodoScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
""",
        """      floatingActionButton: _buildFab(context),
""",
    )
    replace_exact(
        path,
        """          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                settings: context.read<AppSettings>(),
              ),
            ),
          );
""",
        """          pushAdaptive<void>(
            context,
            (_) => SettingsScreen(
              settings: context.read<AppSettings>(),
            ),
          );
""",
    )
    insert_once(
        path,
        "}\n\nclass _MainBottomNav extends StatelessWidget {",
        """  Widget _buildFab(BuildContext context) {
    final button = FloatingActionButton.extended(
      onPressed: () => pushAdaptive<void>(
        context,
        (_) => const AddTodoScreen(),
      ),
      icon: const Icon(Icons.add),
      label: const Text('追加'),
    );
    if (context.isReducedMotion) return button;

    return Listener(
      onPointerDown: (_) => _setFabPressed(true),
      onPointerUp: (_) => _setFabPressed(false),
      onPointerCancel: (_) => _setFabPressed(false),
      child: AnimatedScale(
        duration: AppMotion.quick,
        curve: AppMotion.standardCurve,
        scale: _fabPressed ? 0.96 : 1,
        child: button,
      ),
    );
  }

  void _setFabPressed(bool pressed) {
    if (!mounted || _fabPressed == pressed) return;
    setState(() => _fabPressed = pressed);
  }

""",
    )


def apply_home_scope() -> None:
    path = 'lib/src/screens/home_screen_scope.dart'
    replace_exact(
        path,
        "import '../app_state.dart';\n",
        "import '../app_navigation.dart';\nimport '../app_state.dart';\n",
    )
    replace_exact(
        path,
        """          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => screen),
          );
""",
        """          await pushAdaptive<void>(context, (_) => screen);
""",
    )


def apply_add_todo() -> None:
    path = 'lib/src/screens/add_todo_screen.dart'
    replace_exact(
        path,
        "import '../app_state.dart';\n",
        "import '../app_navigation.dart';\nimport '../app_state.dart';\n",
    )
    replace_exact(
        path,
        """    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            _reviewScreenFor(drafts: drafts, documentId: document.id),
      ),
    );
""",
        """    await navigator.pushReplacement<void, void>(
      adaptivePageRoute<void>(
        (_) => _reviewScreenFor(drafts: drafts, documentId: document.id),
      ),
    );
""",
    )
    replace_exact(
        path,
        """          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => _reviewScreenFor(
                drafts: result.drafts,
                documentId: result.document.id,
              ),
            ),
          );
""",
        """          await Navigator.of(context).pushReplacement<void, void>(
            adaptivePageRoute<void>(
              (_) => _reviewScreenFor(
                drafts: result.drafts,
                documentId: result.document.id,
              ),
            ),
          );
""",
    )
    replace_exact(
        path,
        """          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  _reviewScreenFor(drafts: drafts, documentId: document.id),
            ),
          );
""",
        """          await Navigator.of(context).pushReplacement<void, void>(
            adaptivePageRoute<void>(
              (_) => _reviewScreenFor(
                drafts: drafts,
                documentId: document.id,
              ),
            ),
          );
""",
    )


def apply_todo_detail() -> None:
    path = 'lib/src/screens/todo_detail_screen.dart'
    replace_exact(
        path,
        """      body: _isEditing ? _buildEditForm() : _buildDetail(todo, child, document),
""",
        """      body: context.isReducedMotion
          ? (_isEditing
              ? _buildEditForm()
              : _buildDetail(todo, child, document))
          : AnimatedSwitcher(
              duration: AppMotion.standard,
              switchInCurve: AppMotion.standardCurve,
              switchOutCurve: AppMotion.standardCurve,
              child: KeyedSubtree(
                key: ValueKey(_isEditing),
                child: _isEditing
                    ? _buildEditForm()
                    : _buildDetail(todo, child, document),
              ),
            ),
""",
    )
    replace_exact(
        path,
        """        onPressed: () => context.read<AppState>().toggleTodoDone(todo.id),
""",
        """        onPressed: () {
          HapticFeedback.selectionClick();
          context.read<AppState>().toggleTodoDone(todo.id);
        },
""",
    )


def apply_review_extractions() -> None:
    path = 'lib/src/screens/review_extractions_screen.dart'
    replace_exact(
        path,
        "import '../app_state.dart';\n",
        "import '../app_navigation.dart';\nimport '../app_state.dart';\n",
    )
    replace_exact(
        path,
        """    final edited = await Navigator.of(context).push<ExtractionDraft>(
      MaterialPageRoute(
        builder: (_) => ReviewExtractionScreen(
          draft: _reviewState.draftAt(index),
          editOnly: true,
        ),
      ),
    );
""",
        """    final edited = await pushAdaptive<ExtractionDraft>(
      context,
      (_) => ReviewExtractionScreen(
        draft: _reviewState.draftAt(index),
        editOnly: true,
      ),
    );
""",
    )


def apply_bootstrap() -> None:
    path = 'lib/src/bootstrap_app.dart'
    replace_exact(
        path,
        """class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('端末内データを確認しています…'),
          ],
        ),
      ),
    );
  }
}
""",
        """class _BootstrapLoadingScreen extends StatefulWidget {
  const _BootstrapLoadingScreen();

  @override
  State<_BootstrapLoadingScreen> createState() =>
      _BootstrapLoadingScreenState();
}

class _BootstrapLoadingScreenState extends State<_BootstrapLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: AppMotion.standardCurve,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.isReducedMotion) {
      _pulseController
        ..stop()
        ..value = 1;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicator = context.isReducedMotion
        ? const CircularProgressIndicator()
        : ScaleTransition(
            scale: _pulseScale,
            child: const CircularProgressIndicator(),
          );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            const SizedBox(height: 16),
            const Text('端末内データを確認しています…'),
          ],
        ),
      ),
    );
  }
}
""",
    )


def check_onboarding() -> None:
    candidates = [
        ROOT / 'lib/src/screens/onboarding_screen.dart',
        ROOT / 'lib/src/onboarding_screen.dart',
    ]
    existing = [path for path in candidates if path.exists()]
    if not existing:
        print('warning: onboarding_screen.dart is not present on this branch; skipped')
        return
    raise RuntimeError(
        'onboarding_screen.dart exists but its local-only implementation is not available '
        'in the remote base; apply its motion/reduced-motion changes separately.'
    )


def verify_no_material_routes() -> None:
    remaining: list[str] = []
    for path in (ROOT / 'lib/src').rglob('*.dart'):
        if path.name == 'app_navigation.dart':
            continue
        if 'MaterialPageRoute' in path.read_text(encoding='utf-8'):
            remaining.append(str(path.relative_to(ROOT)))
    if remaining:
        raise RuntimeError(f'MaterialPageRoute remains in: {remaining}')


def main() -> None:
    write('lib/src/app_navigation.dart', APP_NAVIGATION)
    apply_app_theme()
    write('lib/src/screens/widgets/todo_tile.dart', TODO_TILE)
    apply_home_screen()
    apply_home_scope()
    apply_add_todo()
    apply_todo_detail()
    apply_review_extractions()
    apply_bootstrap()
    check_onboarding()
    verify_no_material_routes()


if __name__ == '__main__':
    main()
