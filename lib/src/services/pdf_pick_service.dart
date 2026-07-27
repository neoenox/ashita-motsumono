// lib/src/services/pdf_pick_service.dart
// file_picker を使って端末からPDFファイルを選択するサービス。
// 関連: pdf_render_service.dart, document_intake_service.dart, add_todo_screen.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';

typedef PdfPathPicker = Future<String?> Function();

class PdfPickService {
  PdfPickService({PdfPathPicker? picker})
    : _picker = picker ?? _pickPdfPathFromPlatform;

  final PdfPathPicker _picker;

  static Future<String?> _pickPdfPathFromPlatform() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'プリントのPDFを選択',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.xFiles.isEmpty) {
      return null;
    }
    return result.xFiles.single.path;
  }

  Future<File?> pickPdf() async {
    final path = await _picker();
    if (path == null || path.isEmpty) return null;
    return File(path);
  }
}
