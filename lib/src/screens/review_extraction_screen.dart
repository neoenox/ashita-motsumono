// lib/src/screens/review_extraction_screen.dart
// OCR抽出結果の確認・修正画面。タイトル・種類・期限・項目・通知設定を編集して登録。
// OCRは間違う前提で設計。ユーザーが必ず確認してから登録する。
// 関連: screens/add_todo_screen.dart, services/extraction_service.dart, app_state.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';

class ReviewExtractionScreen extends StatefulWidget {
  const ReviewExtractionScreen({
    super.key,
    required this.draft,
    this.documentId,
  });

  final ExtractionDraft draft;
  final String? documentId;

  @override
  State<ReviewExtractionScreen> createState() => _ReviewExtractionScreenState();
}

class _ReviewExtractionScreenState extends State<ReviewExtractionScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _itemsController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TodoCategory _category;
  DateTime? _dueDate;
  String? _childId;
  bool _notifyPreviousNight = true;
  bool _notifySameMorning = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _itemsController = TextEditingController(text: widget.draft.items.join('、'));
    _amountController = TextEditingController(text: widget.draft.amount?.toString() ?? '');
    _noteController = TextEditingController(text: widget.draft.note ?? '');
    _category = widget.draft.category;
    _dueDate = widget.draft.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<AppState>().children;
    return Scaffold(
      appBar: AppBar(title: const Text('読み取り結果の確認')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('OCRは間違う前提です。登録前に内容を確認してください。'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: _childId,
            decoration: const InputDecoration(labelText: '対象', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('未指定')),
              ...children.map((child) => DropdownMenuItem<String?>(value: child.id, child: Text(child.name))),
            ],
            onChanged: (value) => setState(() => _childId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'タイトル', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TodoCategory>(
            value: _category,
            decoration: const InputDecoration(labelText: '種類', border: OutlineInputBorder()),
            items: TodoCategory.values
                .map((category) => DropdownMenuItem(value: category, child: Text(category.label)))
                .toList(),
            onChanged: (value) => setState(() => _category = value ?? TodoCategory.other),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _selectDueDate,
            icon: const Icon(Icons.event),
            label: Text(_dueDate == null
                ? '期限を選ぶ'
                : '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}'),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('前日20:00に通知'),
            value: _notifyPreviousNight,
            onChanged: (value) => setState(() => _notifyPreviousNight = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('当日7:00に通知'),
            value: _notifySameMorning,
            onChanged: (value) => setState(() => _notifySameMorning = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'OCR全文・メモ', border: OutlineInputBorder()),
            minLines: 6,
            maxLines: 12,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('登録する'),
          ),
        ],
      ),
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
    if (result != null) setState(() => _dueDate = result);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    final items = _itemsController.text
        .split(RegExp(r'[,、\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final draft = ExtractionDraft(
      title: title,
      category: _category,
      dueDate: _dueDate,
      amount: int.tryParse(_amountController.text.replaceAll(',', '').trim()),
      items: items,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      rawText: widget.draft.rawText,
    );
    await context.read<AppState>().addTodoFromDraft(
          draft: draft,
          childId: _childId,
          documentId: widget.documentId,
          notifyPreviousNight: _notifyPreviousNight,
          notifySameMorning: _notifySameMorning,
        );
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
