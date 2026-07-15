// test_driver/ocr_verify.dart
// OCR精度を実機/エミュレータで検証するための簡易スクリプト。
// 関連: lib/src/services/ocr_service.dart, lib/src/services/extraction_service.dart

import 'dart:io';

import 'package:ashita_motsumono/src/services/ocr_service.dart';
import 'package:ashita_motsumono/src/services/extraction_service.dart';

Future<void> main() async {
  final imagePath = '/sdcard/Download/test_ocr.png';
  final file = File(imagePath);

  if (!await file.exists()) {
    print('ERROR: test image not found at $imagePath');
    exit(1);
  }

  print('=== OCR Test ===');
  print('Image: $imagePath (${await file.length()} bytes)');

  final ocr = OcrService();
  String ocrText;
  try {
    ocrText = await ocr.recognize(file);
    print('OCR result (${ocrText.length} chars):');
    print('---');
    print(ocrText);
    print('---');
  } catch (e) {
    print('OCR failed: $e');
    exit(1);
  }

  print('');
  print('=== Extraction Result ===');
  final draft = ExtractionService.extract(ocrText);
  print('Title: ${draft.title}');
  print('Category: ${draft.category.label}');
  print('Due date: ${draft.dueDate}');
  print('Amount: ${draft.amount}');
  print('Items: ${draft.items}');
  print('Note (first 200): ${draft.note?.substring(0, (draft.note?.length ?? 0).clamp(0, 200))}');

  print('');
  print('=== Multi-extraction ===');
  final drafts = ExtractionService.extractMany(ocrText);
  print('Drafts: ${drafts.length}');
  for (var i = 0; i < drafts.length; i++) {
    final d = drafts[i];
    print('  [$i] ${d.title} | ${d.category.label} | ${d.dueDate} | ${d.amount}円 | items=${d.items}');
  }

  print('');
  print('=== Verifications ===');
  final checks = <String, bool>{};

  // Check Heisei→Western conversion
  checks['平成26年→2014年'] = draft.dueDate?.year == 2014;
  checks['7月10日が抽出される'] = draft.dueDate?.month == 7 && draft.dueDate?.day == 10;
  checks['3,500円が抽出される'] = draft.amount == 3500;
  checks['水筒がitemsに含まれる'] = draft.items.contains('水筒');
  checks['体操着がitemsに含まれる'] = draft.items.contains('体操着');
  checks['帽子がitemsに含まれる'] = draft.items.contains('帽子');
  checks['プールバッグがitemsに含まれる'] = draft.items.contains('プールバッグ');
  checks['集金袋がitemsに含まれる'] = draft.items.contains('集金袋');
  checks['健康観察カードがitemsに含まれる'] = draft.items.contains('健康観察カード');
  checks['申込書がitemsに含まれる'] = draft.items.contains('申込書');
  checks['水着がitemsに含まれる'] = draft.items.contains('水着');
  checks['タオルがitemsに含まれる'] = draft.items.contains('タオル');

  for (final entry in checks.entries) {
    print('  ${entry.value ? "✅" : "❌"} ${entry.key}');
  }

  final passed = checks.values.where((v) => v).length;
  final total = checks.length;
  print('\nResult: $passed/$total passed');
  exit(passed == total ? 0 : 1);
}
