// lib/src/screens/add_todo_screen.dart
// Todo 追加画面。OCR撮影・テキスト貼り付け抽出・手入力の3手段を提供。
// OCR結果は ReviewExtractionScreen に渡して確認後に登録。
// 関連: services/ocr_service.dart, services/extraction_service.dart,
//       services/image_file_service.dart, screens/review_extraction_screen.dart

import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../services/extraction_service.dart';
import '../services/image_file_service.dart';
import '../services/ocr_service.dart';
import '../utils/amount.dart';
import '../utils/date_picker.dart';
import '../utils/string_utils.dart';
import 'review_extraction_screen.dart';
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
    final children = context.watch<AppState>().children;
    return Scaffold(
      appBar: AppBar(title: const Text('追加')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
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
            ChildDropdown(
              value: _personId,
              children: children,
              onChanged: (value) => setState(() => _personId = value),
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
            const SizedBox(height: 24),
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
    final result = await pickDueDate(context, initial: _dueDate);
    if (!mounted || result == null) return;
    setState(() => _dueDate = result);
  }

  Future<void> _saveManual() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    final parsed = parseAmount(_amountController.text);
    if (!parsed.valid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('金額は数字で入力してください')));
      return;
    }

    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final items = splitItems(_itemsController.text);
    final draft = ExtractionDraft(
      title: title,
      category: _category,
      dueDate: _dueDate,
      amount: parsed.amount,
      items: items,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    await appState.addTodoFromDraft(draft: draft, personId: _personId);
    if (!mounted) return;
    navigator.pop();
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
    File? imageFile;
    try {
      final appState = context.read<AppState>();
      final navigator = Navigator.of(context);
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 92);
      if (picked == null) return;
      imageFile = await ImageFileService().copyFromXFile(picked);
      final ocrText = await OcrService().recognize(imageFile);
      if (!mounted) return;
      if (ocrText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文字を読み取れませんでした。撮り直すか、テキスト貼り付けを使ってください。')),
        );
        await ImageFileService.deleteIfExists(imageFile.path);
        imageFile = null;
        return;
      }
      final document = await appState.addDocument(
        sourceType: source == ImageSource.camera ? 'camera' : 'gallery',
        localImagePath: imageFile.path,
        ocrText: ocrText,
      );
      imageFile = null;
      final draft = ExtractionService().extract(ocrText);
      if (!mounted) return;
      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewExtractionScreen(draft: draft, documentId: document.id),
        ),
      );
    } on OcrException catch (e) {
      debugPrint('OCR error: ${e.cause ?? e}');
      await _deleteTemporaryImage(imageFile);
      imageFile = null;
      _showOcrError(e.message);
    } on Object catch (e) {
      debugPrint('OCR error: $e');
      await _deleteTemporaryImage(imageFile);
      imageFile = null;
      _showOcrError('読み取りに失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTemporaryImage(File? imageFile) async {
    if (imageFile == null) return;
    await ImageFileService.deleteIfExists(imageFile.path);
  }

  void _showOcrError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
      ),
    );
  }
}


