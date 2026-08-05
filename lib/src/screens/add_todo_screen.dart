// lib/src/screens/add_todo_screen.dart
// Todo 追加画面。OCR撮影・複数画像・PDF・テキスト貼り付け・手入力を提供。

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../services/app_settings.dart';
import '../services/document_intake_service.dart';
import '../services/extraction_service.dart';
import '../services/gemini_api_service.dart';
import '../services/image_file_service.dart';
import '../services/ocr_pick_service.dart';
import '../services/ocr_service.dart';
import '../services/pdf_pick_service.dart';
import '../services/purchase_provider.dart';
import '../theme/app_theme.dart';
import '../utils/amount.dart';
import '../utils/clipboard_helper.dart';
import '../utils/date_picker.dart';
import '../utils/string_utils.dart';
import '../widgets/intake_progress_overlay.dart';
import 'image_intake_review_screen.dart';
import 'no_candidates_screen.dart';
import 'review_extraction_screen.dart';
import 'review_extractions_screen.dart';
import 'widgets/child_dropdown.dart';

part 'add_todo_screen_layout.dart';
part 'add_todo_screen_actions.dart';
part 'add_todo_image_review_actions.dart';

@visibleForTesting
Future<void> requestAiImageAnalysisWithDisclosure(
  BuildContext context, {
  required Future<void> Function() startAnalysis,
}) async {
  final consent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('AI画像解析について'),
      content: const Text(
        'AI画像解析では、選択した画像と画像形式、解析基準日、タイムゾーンを、'
        'Cloudflare Workersを経由してGoogle Gemini APIへ送信します。\n\n'
        '通常のOCRでは画像を外部送信しません。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('同意して画像を選ぶ'),
        ),
      ],
    ),
  );
  if (!context.mounted || consent != true) return;
  await startAnalysis();
}

class AddTodoScreen extends StatefulWidget {
  const AddTodoScreen({super.key, this.initialText});

  /// 共有インテントやクリップボードから受け取った初期テキスト
  final String? initialText;

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
  bool _cancelRequested = false;
  IntakeProgress? _intakeProgress;
  IntakeCancellationToken? _cancellationToken;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _pasteController.text = widget.initialText!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _extractFromText(widget.initialText!);
      });
    }
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _titleController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  void _update(VoidCallback callback) => setState(callback);

  @override
  Widget build(BuildContext context) => _buildContent(context);
}
