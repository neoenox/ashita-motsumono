import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../services/app_settings.dart';
import '../services/extraction_service.dart';
import '../theme/app_theme.dart';
import '../utils/amount.dart';
import '../utils/date_picker.dart';
import '../utils/string_utils.dart';
import 'review_extraction_screen.dart';
import 'review_extractions_screen.dart';
import 'widgets/child_dropdown.dart';

class NoCandidatesScreen extends StatefulWidget {
  const NoCandidatesScreen({
    super.key,
    required this.documentId,
    required this.ocrText,
  });

  final String documentId;
  final String ocrText;

  @override
  State<NoCandidatesScreen> createState() => _NoCandidatesScreenState();
}

class _NoCandidatesScreenState extends State<NoCandidatesScreen> {
  late final TextEditingController _ocrController;
  final _titleController = TextEditingController();
  final _itemsController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  AppState? _appState;
  DateTime? _dueDate;
  TodoCategory _category = TodoCategory.item;
  String? _personId;
  bool _editingOcr = false;
  bool _saved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ocrController = TextEditingController(text: widget.ocrText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void dispose() {
    final appState = _appState;
    if (appState != null) {
      unawaited(
        appState.tryDeleteDocumentOnDispose(
          saved: _saved,
          documentId: widget.documentId,
        ),
      );
    }
    _ocrController.dispose();
    _titleController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = context.watch<AppState>().children;

    return Scaffold(
      appBar: AppBar(title: const Text('読み取り結果を手入力')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.md,
          Spacing.md,
          96,
        ),
        children: [
          Card(
            color: cs.primaryContainer.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: cs.primary, size: 20),
                  const SizedBox(width: Spacing.sm),
                  const Expanded(
                    child: Text(
                      'Todo候補を自動抽出できませんでした。OCR全文を確認し、手入力するか、全文を編集して再抽出してください。',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text('OCR全文', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          TextField(
            controller: _ocrController,
            readOnly: !_editingOcr,
            enabled: !_busy,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              hintText: '文字を読み取れませんでした。画像を確認しながら手入力してください。',
              helperText: _editingOcr
                  ? '抽出しやすいように誤字や改行を修正できます。'
                  : '読み取り結果は端末内に保存されています。',
              suffixIcon: _editingOcr
                  ? const Icon(Icons.edit_outlined)
                  : const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _editOrReextract,
                  icon: Icon(_editingOcr ? Icons.auto_fix_high : Icons.edit),
                  label: Text(_editingOcr ? '編集した全文から再抽出' : '全文を編集して再抽出'),
                ),
              ),
              if (_editingOcr) ...[
                const SizedBox(width: Spacing.sm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _ocrController.text = widget.ocrText;
                          setState(() => _editingOcr = false);
                        },
                  child: const Text('元に戻す'),
                ),
              ],
            ],
          ),
          const SizedBox(height: Spacing.lg),
          const Divider(),
          const SizedBox(height: Spacing.md),
          Text('手入力', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          ChildDropdown(
            value: _personId,
            children: children,
            onChanged: _busy
                ? null
                : (value) => setState(() => _personId = value),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _titleController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'タイトル',
              hintText: '例：集金袋を提出',
            ),
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
            onChanged: _busy
                ? null
                : (value) =>
                      setState(() => _category = value ?? TodoCategory.other),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _selectDueDate,
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
                  onPressed: _busy
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
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: '持ち物・チェック項目',
              hintText: '水筒、体操着、集金袋',
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _amountController,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: '金額', hintText: '500'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _noteController,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'メモ'),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton.icon(
            onPressed: _busy ? null : _saveManual,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_busy ? '登録中...' : '手入力内容を登録'),
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

  Future<void> _editOrReextract() async {
    if (!_editingOcr) {
      setState(() => _editingOcr = true);
      return;
    }

    final text = _ocrController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('再抽出するテキストを入力してください')));
      return;
    }

    final drafts = ExtractionService.extractMany(
      text,
      learnedItemLabels: context.read<AppSettings>().learnedItemLabels,
    );
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todo候補を抽出できませんでした。編集を続けるか、手入力してください。')),
      );
      return;
    }

    _saved = true;
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _reviewScreenFor(
          drafts: drafts,
          documentId: widget.documentId,
        ),
      ),
    );
  }

  Future<void> _saveManual() async {
    if (_busy) return;
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

    setState(() => _busy = true);
    final items = splitItems(_itemsController.text);
    final note = _noteController.text.trim();
    final draft = ExtractionDraft(
      title: title,
      category: _category,
      dueDate: _dueDate,
      amount: parsed.amount,
      items: items,
      note: note.isEmpty ? null : note,
      rawText: _ocrController.text.trim(),
    );

    try {
      final appState = context.read<AppState>();
      final settings = context.read<AppSettings>();
      await appState.addTodoFromDraft(
        draft: draft,
        personId: _personId,
        documentId: widget.documentId,
      );
      await settings.addLearnedItemLabels(items);
      _saved = true;
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登録に失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _reviewScreenFor({
    required List<ExtractionDraft> drafts,
    required String documentId,
  }) {
    if (drafts.length == 1) {
      return ReviewExtractionScreen(
        draft: drafts.single,
        documentId: documentId,
      );
    }
    return ReviewExtractionsScreen(drafts: drafts, documentId: documentId);
  }
}
