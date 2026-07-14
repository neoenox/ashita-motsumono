// lib/ocr_test_main.dart
// OCR精度検証用エントリポイント。
// エミュレータに画像をpushして flutter run --target lib/ocr_test_main.dart で実行。
// 関連: services/ocr_service.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/services/ocr_service.dart';
import 'src/services/extraction_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OcrTestApp());
}

class _OcrTestApp extends StatelessWidget {
  const _OcrTestApp();
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: _OcrTestScreen());
}

class _OcrTestScreen extends StatefulWidget {
  const _OcrTestScreen();
  @override
  State<_OcrTestScreen> createState() => _OcrTestScreenState();
}

class _OcrTestScreenState extends State<_OcrTestScreen> {
  String _log = 'Starting OCR test...';
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runOcrTest());
  }

  void _logLine(String line) {
    setState(() => _log += '\n$line');
    debugPrint('OCR_TEST: $line');
  }

  Future<void> _runOcrTest() async {
    final imagePaths = [
      '/data/data/com.ashita_motsumono/files/document_images/test_ocr.png',
      '/sdcard/Download/test_ocr.png',
    ];

    File? imageFile;
    for (final path in imagePaths) {
      final f = File(path);
      if (await f.exists()) {
        imageFile = f;
        break;
      }
    }

    if (imageFile == null) {
      _logLine('❌ Test image not found. Push it first:');
      _logLine('   adb push test_ocr.png /sdcard/Download/');
      return;
    }

    _logLine(
      '✅ Image found: ${imageFile.path} (${await imageFile.length()} bytes)',
    );
    _logLine('');

    final ocr = OcrService();
    String ocrText;
    try {
      _logLine('🔄 Running OCR...');
      ocrText = await ocr.recognize(imageFile);
      _logLine('✅ OCR done (${ocrText.length} chars)');
      _logLine('');
      _logLine('=== RAW OCR TEXT ===');
      _logLine(ocrText);
      _logLine('=== END ===');
    } catch (e) {
      _logLine('❌ OCR failed: $e');
      if (e is MissingPluginException) {
        _logLine('\n💡 The emulator may need Google Play Services for ML Kit.');
        _logLine('   Try: Install Google Play Services on the emulator.');
      }
      return;
    }

    _logLine('');
    _logLine('=== EXTRACTION ===');

    final draft = ExtractionService.extract(ocrText);
    _logLine('  Title: ${draft.title}');
    _logLine('  Category: ${draft.category.label}');
    _logLine('  DueDate: ${draft.dueDate}');
    _logLine('  Amount: ${draft.amount}');
    _logLine('  Items: ${draft.items}');

    _logLine('');
    _logLine('=== MULTI EXTRACTION ===');
    final drafts = ExtractionService.extractMany(ocrText);
    _logLine('  Drafts: ${drafts.length}');
    for (var i = 0; i < drafts.length; i++) {
      final d = drafts[i];
      _logLine(
        '  [$i] ${d.title} | ${d.category.label} | ${d.dueDate} | ${d.amount}円',
      );
    }

    _logLine('');
    _logLine('=== VERIFICATION ===');
    final checks = <String, bool>{
      '平成26年→2014': draft.dueDate?.year == 2014,
      '7/10 抽出': draft.dueDate?.month == 7 && draft.dueDate?.day == 10,
      '3,500円': draft.amount == 3500,
      '水筒': draft.items.contains('水筒'),
      '体操着': draft.items.contains('体操着'),
      '帽子': draft.items.contains('帽子'),
      'プールバッグ': draft.items.contains('プールバッグ'),
      '集金袋': draft.items.contains('集金袋'),
      '健康観察カード': draft.items.contains('健康観察カード'),
      '申込書': draft.items.contains('申込書'),
    };

    final passed = checks.values.where((v) => v).length;
    for (final e in checks.entries) {
      _logLine('  ${e.value ? "✅" : "❌"} ${e.key}');
    }
    _logLine('\n📊 Result: $passed/${checks.length} passed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR Test')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _log,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}
