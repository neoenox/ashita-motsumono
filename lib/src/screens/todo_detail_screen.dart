// lib/src/screens/todo_detail_screen.dart
// Todo 詳細画面兼編集画面。表示/編集モードを切り替え可能。
// 編集モードではタイトル・種類・期限・金額を変更できる。
// 関連: screens/home_screen.dart, app_state.dart, utils/date_formatters.dart

import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../utils/date_formatters.dart';

class TodoDetailScreen extends StatefulWidget {
  const TodoDetailScreen({super.key, required this.todoId});

  final String todoId;

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _itemsController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late TodoCategory _category;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _itemsController = TextEditingController();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _category = TodoCategory.other;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _startEdit(AppTodo todo) {
    _titleController.text = todo.title;
    _itemsController.text = todo.items.map((e) => e.label).join('、');
    _amountController.text = todo.amount?.toString() ?? '';
    _noteController.text = todo.note ?? '';
    _category = todo.category;
    _dueDate = todo.dueDate;
    setState(() => _isEditing = true);
  }

  Future<void> _saveEdit(AppTodo todo) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final amountText = _amountController.text.replaceAll(',', '').trim();
    final amount = amountText.isEmpty ? null : int.tryParse(amountText);
    if (amountText.isNotEmpty && amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('金額は数字で入力してください')));
      return;
    }

    final appState = context.read<AppState>();
    final noteText = _noteController.text.trim();
    final items = _itemsController.text
        .split(RegExp(r'[,、\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((label) {
      final existing = todo.items.where((i) => i.label == label).firstOrNull;
      return existing ?? ChecklistItem(id: const Uuid().v4(), label: label);
    }).toList();
    final updated = todo.copyWith(
      title: title,
      category: _category,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
      amount: amount,
      clearAmount: amountText.isEmpty,
      note: noteText.isEmpty ? null : noteText,
      clearNote: noteText.isEmpty,
      items: items,
      updatedAt: DateTime.now(),
    );
    await appState.updateTodo(updated);
    if (!mounted) return;
    setState(() => _isEditing = false);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  Future<void> _confirmDelete(AppTodo todo) async {
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${todo.title}」を削除しますか？\n元画像がこのTodoだけで使われている場合は画像も削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (!mounted || result != true) return;
    await appState.deleteTodo(todo.id);
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final todo = state.todos.where((e) => e.id == widget.todoId).firstOrNull;
    if (todo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Todo詳細')),
        body: const Center(child: Text('Todoが見つかりませんでした')),
      );
    }

    final child = state.childById(todo.childId);
    final document = state.documentById(todo.documentId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Todo編集' : 'Todo詳細'),
        actions: [
          if (_isEditing) ...[
            IconButton(icon: const Icon(Icons.close), onPressed: _cancelEdit),
            IconButton(icon: const Icon(Icons.check), onPressed: () => _saveEdit(todo)),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _startEdit(todo),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(todo),
            ),
          ],
        ],
      ),
      body: _isEditing ? _buildEditForm() : _buildDetail(todo, child, document),
    );
  }

  Widget _buildDetail(AppTodo todo, ChildProfile? child, DocumentRecord? document) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(todo.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('種類：${todo.category.label}'),
                Text('期限：${formatDueDate(todo.dueDate)}'),
                if (child != null) Text('対象：${child.name}'),
                if (todo.amount != null) Text('金額：${todo.amount}円'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.read<AppState>().toggleTodoDone(todo.id),
                  icon: Icon(todo.isDone ? Icons.undo : Icons.check),
                  label: Text(todo.isDone ? '未完了に戻す' : '完了にする'),
                ),
              ],
            ),
          ),
        ),
        if (todo.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('チェック項目', style: Theme.of(context).textTheme.titleMedium),
                  ...todo.items.map(
                    (item) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: item.isChecked,
                      title: Text(item.label),
                      onChanged: (_) => context.read<AppState>().toggleItem(todo.id, item.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (todo.note != null && todo.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('メモ・OCR全文', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText(todo.note!),
                ],
              ),
            ),
          ),
        ],
        if (document?.localImagePath != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('元画像', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (kIsWeb)
                    const Text('（Web版では画像表示は利用できません）')
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(document!.localImagePath!)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'タイトル', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TodoCategory>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: '種類', border: OutlineInputBorder()),
          items: TodoCategory.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (value) => setState(() => _category = value ?? TodoCategory.other),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectDueDate,
                icon: const Icon(Icons.event),
                label: Text(_dueDate == null ? '期限を選ぶ' : '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}'),
              ),
            ),
            if (_dueDate != null) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: '期限をクリア',
                onPressed: () => setState(() => _dueDate = null),
                icon: const Icon(Icons.clear),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _itemsController,
          decoration: const InputDecoration(
            labelText: '持ち物・チェック項目',
            border: OutlineInputBorder(),
            hintText: '水筒、体操着、集金袋',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(labelText: '金額', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'メモ', border: OutlineInputBorder()),
          minLines: 3,
          maxLines: 6,
        ),
      ],
    );
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: _dueDate ?? now,
    );
    if (!mounted || result == null) return;
    setState(() => _dueDate = result);
  }
}
