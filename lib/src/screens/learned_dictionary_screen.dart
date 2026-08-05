// lib/src/screens/learned_dictionary_screen.dart
// OCR候補登録で学習した持ち物ラベルを確認し、個別削除・全消去・取り消しを行う。

import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_theme.dart';

class LearnedDictionaryScreen extends StatelessWidget {
  const LearnedDictionaryScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('読み取り辞書')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          final labels = settings.learnedItemLabels;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.xl,
            ),
            children: [
              Card(
                color: cs.primaryContainer.withValues(alpha: 0.25),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.spellcheck, color: cs.primary),
                      const SizedBox(width: Spacing.sm),
                      const Expanded(
                        child: Text(
                          '登録した持ち物を読み取り候補として学習します。誤って登録した語はここから削除できます。',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '学習済み ${labels.length}件',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (labels.isNotEmpty)
                    TextButton.icon(
                      key: const ValueKey('clear-learned-dictionary'),
                      onPressed: () => _confirmClear(context),
                      icon: Icon(Icons.delete_sweep_outlined, color: cs.error),
                      label: Text('すべて削除', style: TextStyle(color: cs.error)),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              if (labels.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Column(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 44,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: Spacing.sm),
                        const Text('学習した語はまだありません'),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          'Todoを登録すると、持ち物が最大100件まで学習されます。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var index = 0; index < labels.length; index++) ...[
                        ListTile(
                          key: ValueKey('learned-label-${labels[index]}'),
                          leading: const Icon(Icons.label_outline),
                          title: Text(labels[index]),
                          trailing: IconButton(
                            key: ValueKey('remove-learned-label-${labels[index]}'),
                            tooltip: '辞書から削除',
                            onPressed: () => _remove(context, labels[index]),
                            icon: Icon(Icons.close, color: cs.error),
                          ),
                        ),
                        if (index < labels.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _remove(BuildContext context, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await settings.removeLearnedItemLabel(label);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('「$label」を辞書から削除しました'),
          action: SnackBarAction(
            label: '元に戻す',
            onPressed: () async {
              await settings.addLearnedItemLabels([label]);
            },
          ),
        ),
      );
    } on Object {
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('辞書から削除できませんでした')));
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('読み取り辞書をすべて削除'),
        content: const Text('学習した持ち物をすべて削除します。登録済みのTodoには影響しません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('すべて削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await settings.clearLearnedItemLabels();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('読み取り辞書を削除しました')));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('読み取り辞書を削除できませんでした')));
    }
  }
}
