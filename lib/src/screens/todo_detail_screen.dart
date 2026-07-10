// lib/src/screens/todo_detail_screen.dart
// Todo 詳細画面兼編集画面。表示/編集モードを切り替え可能。
// Stitch デザインに合わせてカードベースのレイアウトに刷新。
// 関連: screens/home_screen.dart, app_state.dart, utils/date_formatters.dart

import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../utils/amount.dart';
import '../utils/date_picker.dart';
import '../utils/string_utils.dart';
import '../app_state.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';

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

    final parsed = parseAmount(_amountController.text);
    if (!parsed.valid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金額は数字で入力してください')));
      return;
    }

    final appState = context.read<AppState>();
    final settings = context.read<AppSettings>();
    final noteText = _noteController.text.trim();
    final items = splitItems(_itemsController.text).map((label) {
      final existing = todo.items.where((i) => i.label == label).firstOrNull;
      return existing ?? ChecklistItem(id: const Uuid().v4(), label: label);
    }).toList();
    final updated = todo.copyWith(
      title: title,
      category: _category,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
      amount: parsed.amount,
      clearAmount: parsed.amount == null,
      note: noteText.isEmpty ? null : noteText,
      clearNote: noteText.isEmpty,
      items: items,
      updatedAt: DateTime.now(),
    );
    await appState.updateTodo(updated);
    await settings.addLearnedItemLabels(items.map((item) => item.label));
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
        content: Text(
          '「${todo.title}」を削除しますか？\n元画像がこのTodoだけで使われている場合は画像も削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
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

    final child = state.personById(todo.personId);
    final document = state.documentById(todo.documentId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Todo編集' : 'Todo詳細'),
        actions: [
          if (_isEditing) ...[
            IconButton(icon: const Icon(Icons.close), onPressed: _cancelEdit),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => _saveEdit(todo),
            ),
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

  Widget _buildDetail(
    AppTodo todo,
    PersonProfile? child,
    DocumentRecord? document,
  ) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        _buildInfoCard(todo, child),
        const SizedBox(height: Spacing.md),
        _buildCompletionButton(todo),
        if (todo.items.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          _buildChecklistSection(todo),
        ],
        if (todo.note != null && todo.note!.trim().isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          _buildNoteSection(todo.note!),
        ],
        const SizedBox(height: Spacing.md),
        _buildImageSection(document),
        const SizedBox(height: Spacing.md),
        _buildActionButtons(todo),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Text('$label：', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(width: Spacing.xs),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppTodo todo, PersonProfile? child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: todo.category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                todo.category.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: todo.category.color,
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(todo.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            _detailRow(Icons.event, '期限', formatDueDate(todo.dueDate)),
            if (child != null) _detailRow(Icons.person, '対象', child.name),
            if (todo.amount != null)
              _detailRow(Icons.monetization_on_outlined, '金額', '${todo.amount}円'),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionButton(AppTodo todo) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => context.read<AppState>().toggleTodoDone(todo.id),
        icon: Icon(todo.isDone ? Icons.undo : Icons.check_circle),
        label: Text(todo.isDone ? '未完了に戻す' : '完了にする'),
      ),
    );
  }

  Widget _buildChecklistSection(AppTodo todo) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, size: 18),
                const SizedBox(width: Spacing.sm),
                Text('チェック項目',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${todo.items.where((i) => i.isChecked).length}/${todo.items.length}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            ...todo.items.map(
              (item) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: item.isChecked,
                title: Text(item.label),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (_) =>
                    context.read<AppState>().toggleItem(todo.id, item.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection(String note) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 18),
                const SizedBox(width: Spacing.sm),
                Text('メモ・OCR全文',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            SelectableText(note),
            const SizedBox(height: Spacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: note));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('全文をコピーしました')),
                );
              },
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('全文をコピー'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(DocumentRecord? document) {
    final cs = Theme.of(context).colorScheme;
    if (document?.localImagePath != null) {
      final imageFile = File(document!.localImagePath!);
      final screenWidth = MediaQuery.of(context).size.width;
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final cacheWidth = (screenWidth * devicePixelRatio).round();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.image_outlined, size: 18),
                  const SizedBox(width: Spacing.sm),
                  Text('元画像',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageFile.existsSync()
                    ? Image.file(imageFile, cacheWidth: cacheWidth)
                    : Container(
                        height: 120,
                        color: cs.surfaceContainerLow,
                        child: Center(
                          child: Text(
                            '画像ファイルが見つかりません',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            const Icon(Icons.image_outlined, size: 18),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'OCRスキャン元画像の履歴はありません',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppTodo todo) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmDelete(todo),
        icon: Icon(Icons.delete_outline, size: 16),
        label: const Text('削除'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'タイトル'),
        ),
        const SizedBox(height: Spacing.md),
        DropdownButtonFormField<TodoCategory>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: '種類'),
          items: TodoCategory.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (value) =>
              setState(() => _category = value ?? TodoCategory.other),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectDueDate,
                icon: const Icon(Icons.event),
                label: Text(
                  _dueDate == null
                      ? '期限を選ぶ'
                      : '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}',
                ),
              ),
            ),
            if (_dueDate != null) ...[
              const SizedBox(width: Spacing.sm),
              IconButton.outlined(
                tooltip: '期限をクリア',
                onPressed: () => setState(() => _dueDate = null),
                icon: const Icon(Icons.clear),
              ),
            ],
          ],
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _itemsController,
          decoration: const InputDecoration(
            labelText: '持ち物・チェック項目',
            hintText: '水筒、体操着、集金袋',
          ),
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(labelText: '金額'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'メモ'),
          minLines: 3,
          maxLines: 6,
        ),
      ],
    );
  }

  Future<void> _selectDueDate() async {
    final result = await pickDueDate(context, initial: _dueDate);
    if (!mounted || result == null) return;
    setState(() => _dueDate = result);
  }
}
