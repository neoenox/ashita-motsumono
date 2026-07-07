// lib/src/screens/review_extraction_screen.dart
// OCR抽出結果の確認・修正画面。タイトル・種類・期限・項目・通知設定を編集して登録。
// OCRは間違う前提で設計。ユーザーが必ず確認してから登録する。
// 関連: screens/add_todo_screen.dart, services/extraction_service.dart, app_state.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/amount.dart';
import '../utils/date_picker.dart';
import '../utils/string_utils.dart';
import '../app_state.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';

import '../models/entities.dart';
import 'widgets/child_dropdown.dart';

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
  late AppState _appState;
  late TodoCategory _category;
  DateTime? _dueDate;
  String? _personId;
  bool _notifyPreviousNight = true;
  bool _notifySameMorning = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _itemsController = TextEditingController(
      text: widget.draft.items.join('、'),
    );
    _amountController = TextEditingController(
      text: widget.draft.amount?.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.draft.note ?? '');
    _category = widget.draft.category;
    _dueDate = widget.draft.dueDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void dispose() {
    if (!_saved && widget.documentId != null) {
      unawaited(
        _appState
            .deleteDocument(widget.documentId!)
            .then((deleted) {
              if (kDebugMode) {
                debugPrint(
                  'Document cleanup on dispose: ${deleted ? "deleted" : "still in use"}',
                );
              }
            })
            .catchError((e) {
              if (kDebugMode) {
                debugPrint('Failed to clean up document on dispose: $e');
              }
            }),
      );
    }
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
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          const Text('OCRは間違う前提です。登録前に内容を確認してください。'),
          const SizedBox(height: Spacing.md),
          ChildDropdown(
            value: _personId,
            children: children,
            onChanged: (value) => setState(() => _personId = value),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'タイトル',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: Spacing.md),
          DropdownButtonFormField<TodoCategory>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: '種類',
              border: OutlineInputBorder(),
            ),
            items: TodoCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
                )
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
              border: OutlineInputBorder(),
              hintText: '水筒、体操着、集金袋',
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: '金額',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: Spacing.md),
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
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'OCR全文・メモ',
              border: OutlineInputBorder(),
            ),
            minLines: 6,
            maxLines: 12,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('登録する'),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final result = await pickDueDate(context, initial: _dueDate);
    if (!mounted || result == null) return;
    setState(() => _dueDate = result);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    final parsed = parseAmount(_amountController.text);
    if (!parsed.valid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金額は数字で入力してください')));
      return;
    }

    final appState = context.read<AppState>();
    final settings = context.read<AppSettings>();
    final navigator = Navigator.of(context);
    final items = splitItems(_itemsController.text);
    final draft = ExtractionDraft(
      title: title,
      category: _category,
      dueDate: _dueDate,
      amount: parsed.amount,
      items: items,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      rawText: widget.draft.rawText,
    );
    await appState.addTodoFromDraft(
      draft: draft,
      personId: _personId,
      documentId: widget.documentId,
      notifyPreviousNight: _notifyPreviousNight,
      notifySameMorning: _notifySameMorning,
    );
    await settings.addLearnedItemLabels(items);
    _saved = true;
    if (!mounted) return;
    navigator.popUntil((route) => route.isFirst);
  }
}
