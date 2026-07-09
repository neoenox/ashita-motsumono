// lib/src/screens/add_todo_screen.dart
// Todo 追加画面。OCR撮影・テキスト貼り付け抽出・手入力の3手段を提供。
// Stitch デザインに合わせて OCR ファーストのレイアウトに刷新。
// 関連: services/ocr_pick_service.dart, services/extraction_service.dart,
//       screens/review_extraction_screen.dart

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/extraction_service.dart';
import '../services/ocr_pick_service.dart';
import '../services/ocr_service.dart';
import '../utils/amount.dart';
import '../utils/date_picker.dart';
import '../utils/string_utils.dart';
import 'review_extraction_screen.dart';
import 'review_extractions_screen.dart';
import 'widgets/child_dropdown.dart';

class AddTodoScreen extends StatefulWidget {
  const AddTodoScreen({super.key});

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> {
  final _titleController = TextEditingController();
  final _itemsController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _pasteController = TextEditingController();

  DateTime? _dueDate;
  TodoCategory _category = TodoCategory.item;
  String? _personId;
  bool _busy = false;
  bool _showManual = false;

  @override
  void dispose() {
    _titleController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = context.watch<AppState>().children;
    return Scaffold(
      appBar: AppBar(title: const Text('追加')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.md,
          Spacing.md,
          Spacing.md + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // OCRアシスタントヘッダー
          Card(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: cs.primary, size: 24),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OCRアシスタント有効',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('入力をラクに。お手元の資料やスクリーンショットからTodoを自動生成します。',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // 画像・スクショから登録
          Text('画像・スクショから登録',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.sm),
          if (Platform.isWindows)
            const Padding(
              padding: EdgeInsets.only(bottom: Spacing.sm),
              child: Text('カメラ・OCRはWindows未対応です。テキスト貼り付けまたは手入力を使ってください。',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pickAndOcr(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('写真を撮る'),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pickAndOcr(ImageSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('画像を選ぶ'),
                  ),
                ),
              ],
            ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.md),
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          const SizedBox(height: Spacing.lg),

          // OCRテキスト貼り付け
          Text('OCRテキストを貼り付けて抽出',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.sm),
          TextField(
            controller: _pasteController,
            decoration: InputDecoration(
              hintText: '園アプリやLINE連絡の文面を貼り付け',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Icon(Icons.content_paste, size: 20),
              ),
            ),
            minLines: 4,
            maxLines: 8,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: Spacing.sm),
            child: Text(
              'Powered by OCR Engine',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _extractFromText(_pasteController.text),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('貼り付け文からTodo候補を作る'),
            ),
          ),

          const SizedBox(height: Spacing.lg),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Text('または', style: TextStyle(fontSize: 13)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // 手入力セクション
          if (!_showManual)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showManual = true),
                icon: const Icon(Icons.edit_note),
                label: const Text('手動で入力する'),
              ),
            ),
          if (_showManual) ...[
            const SizedBox(height: Spacing.md),
            Text('手入力', style: Theme.of(context).textTheme.titleMedium),
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
              decoration: const InputDecoration(
                labelText: '金額',
                hintText: '500',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'メモ'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveManual,
                icon: const Icon(Icons.check),
                label: const Text('登録'),
              ),
            ),
          ],

          const SizedBox(height: Spacing.xl),
          Center(
            child: Text(
              '"一日の始まりを、もっと軽やかに。"',
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final result = await pickDueDate(context, initial: _dueDate);
    if (!mounted || result == null) return;
    setState(() => _dueDate = result);
  }

  Future<void> _saveManual() async {
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
    );
    await appState.addTodoFromDraft(draft: draft, personId: _personId);
    await settings.addLearnedItemLabels(items);
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _extractFromText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final appState = context.read<AppState>();
    final settings = context.read<AppSettings>();
    final navigator = Navigator.of(context);
    final drafts = ExtractionService.extractMany(
      trimmed,
      learnedItemLabels: settings.learnedItemLabels,
    );
    if (drafts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テキストからTodo情報を抽出できませんでした。手入力で登録してください。')),
      );
      return;
    }
    final document = await appState.addDocument(
      sourceType: 'text',
      ocrText: trimmed,
    );
    if (!mounted) return;
    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            _reviewScreenFor(drafts: drafts, documentId: document.id),
      ),
    );
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final service = OcrPickService(
        appState: context.read<AppState>(),
        appSettings: context.read<AppSettings>(),
      );
      final result = await service.pickAndProcess(source);
      if (result == null) return;
      if (!mounted) return;
      switch (result) {
        case OcrPickEmpty():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文字を読み取れませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
            ),
          );
        case OcrPickSuccess():
          if (result.drafts.isEmpty) {
            await context.read<AppState>().deleteDocument(result.document.id);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Todo情報を抽出できませんでした。手入力で登録してください。'),
              ),
            );
            return;
          }
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  _reviewScreenFor(drafts: result.drafts, documentId: result.document.id),
            ),
          );
      }
    } on OcrException catch (e) {
      if (kDebugMode) debugPrint('OCR error: ${e.cause ?? e}');
      _showOcrError(e.message);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('OCR error: $e');
      _showOcrError('読み取りに失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showOcrError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 10)),
    );
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
