// lib/src/screens/widgets/home_status_cards.dart
// 初回起動カード、空状態、検索0件、データ破損カード。
// 関連: home_screen.dart, add_child_screen.dart, theme/app_theme.dart

import 'package:flutter/material.dart';

import '../../app_navigation.dart';
import '../../theme/app_theme.dart';
import '../add_child_screen.dart';

class FirstRunCard extends StatelessWidget {
  const FirstRunCard({super.key, this.onAddPerson});

  final VoidCallback? onAddPerson;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 40,
              color: cs.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: Spacing.sm),
            Text('まず人物を登録', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.xs),
            Text(
              'Todoは人物別に整理できます。\nログイン不要・端末内保存です。',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton.icon(
              onPressed:
                  onAddPerson ??
                  () => pushAdaptive<void>(
                    context,
                    (_) => const AddChildScreen(),
                  ),
              icon: const Icon(Icons.add),
              label: const Text('人物を追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.checklist,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Todoがありません',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              '「追加」ボタンから新しくTodoを作成できます',
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoSearchResults extends StatelessWidget {
  const NoSearchResults({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              '「$query」に一致するTodoはありません',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class CorruptDataCard extends StatelessWidget {
  const CorruptDataCard({super.key, required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 18, color: cs.onErrorContainer),
                const SizedBox(width: Spacing.sm),
                Text(
                  '保存データの読み込みに失敗しました',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: cs.onErrorContainer),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              '破損していた保存データは退避されています。復旧確認用にコピーできます。',
              style: TextStyle(color: cs.onErrorContainer),
            ),
            const SizedBox(height: Spacing.md),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: const Text('退避データをコピー'),
            ),
          ],
        ),
      ),
    );
  }
}
