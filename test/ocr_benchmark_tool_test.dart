// test/ocr_benchmark_tool_test.dart
// OCRベンチマーク集計ツールのPython単体テストを通常のFlutter CIへ接続する。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OCR benchmark validator and summarizer tests pass', () async {
    final executable = Platform.isWindows ? 'python' : 'python3';
    final result = await Process.run(executable, const [
      '-m',
      'unittest',
      'tool/ocr_benchmark/test_summarize.py',
    ], workingDirectory: Directory.current.path);

    expect(
      result.exitCode,
      0,
      reason:
          'OCR benchmark Python tests failed.\n'
          'stdout:\n${result.stdout}\n'
          'stderr:\n${result.stderr}',
    );
  });
}
