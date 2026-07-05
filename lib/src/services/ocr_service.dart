// lib/src/services/ocr_service.dart
// Google ML Kit Text Recognition を使って画像から日本語テキストを認識する。
// このMVPは Android/iOS 専用。Web では google_mlkit_text_recognition を使わない。
// 関連: extraction_service.dart, image_file_service.dart, add_todo_screen.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  OcrService();

  Future<String> recognize(File imageFile) async {
    // 画像ファイルの存在・サイズを事前確認（R8最適化や権限問題の早期検知）
    if (!await imageFile.exists()) {
      throw StateError('画像ファイルが見つかりません: ${imageFile.path}');
    }
    final size = await imageFile.length();
    if (size == 0) {
      throw StateError('画像ファイルが空です: ${imageFile.path}');
    }
    debugPrint('OCR: file=${imageFile.path}, size=$size');

    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    try {
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
