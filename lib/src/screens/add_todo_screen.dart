// lib/src/screens/add_todo_screen.dart
// Todo 追加画面。OCR撮影・テキスト貼り付け抽出・手入力の3手段を提供。
// OCR結果は ReviewExtractionScreen に渡して確認後に登録。
// 関連: services/ocr_service.dart, services/extraction_service.dart,
//       services/image_file_service.dart, screens/review_extraction_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../services/extraction_service.dart';
import '../services/image_file_service.dart';
import '../services/ocr_service.dart';
import 'review_extraction_screen.dart';

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
  String? _childId;
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
    final children = context.watch<AppState>().children;
    return Scaffold(
      appBar: AppBar(title: const Text('追加')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('画像・スクショから登録', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickAndOcr(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('写真を撮る'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickAndOcr(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('画像を選ぶ'),
                ),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 24),
          Text('OCRテキストを貼り付けて抽出', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _pasteController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '園アプリやLINE連絡の文面を貼り付け',
            ),
            minLines: 4,
            maxLines: 8,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _extractFromText(_pasteController.text),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('貼り付け文からTodo候補を作る'),
          ),
          const Divider(height: 40),
          if (!_showManual)
            OutlinedButton.icon(
              onPressed: () => setState(() => _showManual = true),
              icon: const Icon(Icons.edit),
              label: const Text('手動で入力する'),
            ),
          if (_showManual) ...[
            Text('手入力', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _ChildDropdown(
              value: _childId,
              children: children,
              onChanged: (value) => setState(() => _childId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
                hintText: '例：集金袋を提出',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TodoCategory>(
              initialValue: _category,
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
              decoration: const InputDecoration(
                labelText: '金額',
                border: OutlineInputBorder(),
                hintText: '500',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'メモ', border: OutlineInputBorder()),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saveManual,
              icon: const Icon(Icons.check),
              label: const Text('登録'),
            ),
          ],
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
    if (!mounted || result == null) return;
    setState(() => _dueDate = result);
  }

  Future<void> _saveManual() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    final parsedAmount = _parseAmountOrShowError(_amountController.text);
    if (!parsedAmount.valid) return;

    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final items = _itemsController.text
        .split(RegExp(r'[,、\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final draft = ExtractionDraft(
      title: title,
      category: _category,
      dueDate: _dueDate,
      amount: parsedAmount.amount,
      items: items,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    await appState.addTodoFromDraft(draft: draft, childId: _childId);
    if (!mounted) return;
    navigator.pop();
  }

  ({bool valid, int? amount}) _parseAmountOrShowError(String value) {
    final amountText = value.replaceAll(',', '').trim();
    if (amountText.isEmpty) return (valid: true, amount: null);
    final amount = int.tryParse(amountText);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('金額は数字で入力してください')));
      return (valid: false, amount: null);
    }
    return (valid: true, amount: amount);
  }

  Future<void> _extractFromText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final draft = ExtractionService().extract(trimmed);
    final document = await appState.addDocument(sourceType: 'text', ocrText: trimmed);
    if (!mounted) return;
    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReviewExtractionScreen(draft: draft, documentId: document.id),
      ),
    );
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final appState = context.read<AppState>();
      final navigator = Navigator.of(context);
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 92);
      if (picked == null) return;
      final imageFile = await ImageFileService().copyFromXFile(picked);
      final ocrText = await OcrService().recognize(imageFile);
      if (!mounted) return;
      if (ocrText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文字を読み取れませんでした。撮り直すか、テキスト貼り付けを使ってください。')),
        );
        await ImageFileService.deleteIfExists(imageFile.path);
        return;
      }
      final document = await appState.addDocument(
        sourceType: source == ImageSource.camera ? 'camera' : 'gallery',
        localImagePath: imageFile.path,
        ocrText: ocrText,
      );
      final draft = ExtractionService().extract(ocrText);
      if (!mounted) return;
      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewExtractionScreen(draft: draft, documentId: document.id),
        ),
      );
    } on Object catch (e) {
      debugPrint('OCR error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('読み取りに失敗しました: $e'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ChildDropdown extends StatelessWidget {
  const _ChildDropdown({required this.value, required this.children, required this.onChanged});

  final String? value;
  final List<ChildProfile> children;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: const InputDecoration(labelText: '対象', border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('未指定')),
        ...children.map((child) => DropdownMenuItem<String?>(value: child.id, child: Text(child.name))),
      ],
      onChanged: onChanged,
    );
  }
}
