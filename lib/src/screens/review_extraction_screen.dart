import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import '../utils/amount.dart';
import '../utils/date_picker.dart';
import '../utils/string_utils.dart';
import 'widgets/child_dropdown.dart';

class ReviewExtractionScreen extends StatefulWidget {
  const ReviewExtractionScreen({
    super.key,
    required this.draft,
    this.documentId,
    this.editOnly = false,
  });

  final ExtractionDraft draft;
  final String? documentId;
  final bool editOnly;

  @override
  State<ReviewExtractionScreen> createState() => _ReviewExtractionScreenState();
}

String _fmtTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

class _ReviewExtractionScreenState extends State<ReviewExtractionScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _itemsController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  AppState? _appState;
  late TodoCategory _category;
  DateTime? _dueDate;
  String? _personId;
  bool _notifyPreviousNight = true;
  bool _notifySameMorning = true;
  bool _saved = false;
  bool _saving = false;

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
    if (!widget.editOnly && _appState != null) {
      unawaited(
        _appState!.tryDeleteDocumentOnDispose(
          saved: _saved,
          documentId: widget.documentId,
        ),
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
      appBar: AppBar(title: Text(widget.editOnly ? '候補を編集' : '読み取り結果の確認')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.md,
          Spacing.md,
          96,
        ),
        children: [
          Card(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      widget.editOnly
                          ? 'この候補の内容を修正し、一覧へ反映します。'
                          : 'OCRは間違う前提です。登録前に内容を確認してください。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!widget.editOnly) ...[
            const SizedBox(height: Spacing.md),
            ChildDropdown(
              value: _personId,
              children: children,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _personId = value),
            ),
          ],
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _titleController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'タイトル'),
          ),
          const SizedBox(height: Spacing.md),
          DropdownButtonFormField<TodoCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: '種類'),
            items: TodoCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) =>
                      setState(() => _category = value ?? TodoCategory.other),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _selectDueDate,
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
                  onPressed: _saving
                      ? null
                      : () => setState(() => _dueDate = null),
                  icon: const Icon(Icons.clear),
                ),
              ],
            ],
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _itemsController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: '持ち物・チェック項目',
              hintText: '水筒、体操着、集金袋',
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _amountController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: '金額', hintText: '500'),
            keyboardType: TextInputType.number,
          ),
          if (!widget.editOnly) ...[
            const SizedBox(height: Spacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '前日${_fmtTime(context.read<AppSettings>().previousNightHour, context.read<AppSettings>().previousNightMinute)}に通知',
                      ),
                      subtitle: const Text('前日夜にリマインド'),
                      value: _notifyPreviousNight,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _notifyPreviousNight = value),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '当日${_fmtTime(context.read<AppSettings>().sameMorningHour, context.read<AppSettings>().sameMorningMinute)}に通知',
                      ),
                      subtitle: const Text('当日朝にリマインド'),
                      value: _notifySameMorning,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _notifySameMorning = value),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _noteController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'OCR全文・メモ'),
            minLines: 6,
            maxLines: 12,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(widget.editOnly ? Icons.save_outlined : Icons.check),
            label: Text(
              _saving
                  ? '保存中…'
                  : widget.editOnly
                  ? '変更を反映'
                  : '登録する',
            ),
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
    if (_saving) return;
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

    final navigator = Navigator.of(context);
    final items = splitItems(_itemsController.text);
    final note = _noteController.text.trim();
    final draft = ExtractionDraft(
      title: title,
      category: _category,
      dueDate: _dueDate,
      amount: parsed.amount,
      items: items,
      note: note.isEmpty ? null : note,
      rawText: widget.draft.rawText,
    );

    if (widget.editOnly) {
      _saved = true;
      navigator.pop(draft);
      return;
    }

    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      final settings = context.read<AppSettings>();
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
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登録に失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
