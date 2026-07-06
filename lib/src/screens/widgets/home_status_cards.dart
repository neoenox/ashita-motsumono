// lib/src/screens/widgets/home_status_cards.dart
// 初回起動カード、空状態、検索0件、データ破損カード。
// 関連: home_screen.dart, add_child_screen.dart

import 'package:flutter/material.dart';

import '../add_child_screen.dart';

class FirstRunCard extends StatelessWidget {
  const FirstRunCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('まず人物を登録', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Todoは人物別に整理できます。MVPではログインなし・端末内保存です。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddChildScreen()),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Todoがありません',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('「追加」ボタンから新しくTodoを作成できます',
                style: TextStyle(color: Colors.grey[400])),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('「$query」に一致するTodoはありません',
                style: TextStyle(color: Colors.grey[500])),
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
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('保存データの読み込みに失敗しました',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('破損していた保存データは退避されています。復旧確認用にコピーできます。'),
            const SizedBox(height: 12),
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
