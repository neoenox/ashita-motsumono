// lib/src/screens/add_child_screen.dart
// 子どもを追加・削除する画面。名前入力と登録済み一覧表示。
// 削除は確認ダイアログで実行。関連するTodoの子ども指定はクリアされる。
// 関連: screens/home_screen.dart, app_state.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<AppState>().children;
    return Scaffold(
      appBar: AppBar(title: const Text('子ども管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: '子どもの名前',
              hintText: '例：長女、太郎、保育園用',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(context),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
          const SizedBox(height: 24),
          Text('登録済み', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (children.isEmpty)
            const Text('まだ登録されていません。')
          else
            ...children.map(
              (child) => ListTile(
                leading: CircleAvatar(backgroundColor: Color(child.colorValue)),
                title: Text(child.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _startEdit(context, child),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, child.id, child.name),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    if (_hasDuplicateName(appState.children, name)) {
      messenger.showSnackBar(const SnackBar(content: Text('同じ名前がすでに登録されています')));
      return;
    }
    await appState.addChild(name);
    _controller.clear();
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('追加しました')));
    }
  }

  Future<void> _startEdit(BuildContext context, ChildProfile child) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: child.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('名前を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '子どもの名前',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null || result.isEmpty) return;
    if (_hasDuplicateName(appState.children, result, exceptId: child.id)) {
      messenger.showSnackBar(const SnackBar(content: Text('同じ名前がすでに登録されています')));
      return;
    }
    await appState.updateChild(child.copyWith(name: result));
  }

  bool _hasDuplicateName(List<ChildProfile> children, String name, {String? exceptId}) {
    return children.any((child) => child.id != exceptId && child.name == name);
  }

  Future<void> _confirmDelete(BuildContext context, String id, String name) async {
    final appState = context.read<AppState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('$name を削除しますか？\n関連するTodoは対象の子ども指定がクリアされます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (result == true && mounted) {
      await appState.deleteChild(id);
    }
  }
}
