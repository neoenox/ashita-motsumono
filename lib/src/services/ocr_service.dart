// lib/src/services/ocr_service.dart
// Google ML Kit Text Recognition を使って画像から日本語テキストを認識する。
// このMVPは Android/iOS 専用。Web では google_mlkit_text_recognition を使わない。
// 関連: extraction_service.dart, image_file_service.dart, add_todo_screen.dart

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  OcrService();

  Future<String> recognize(File imageFile) async {
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
