// lib/src/services/ocr_service.dart
// Google ML Kit Text Recognition を使って画像から日本語テキストを認識する。
// このMVPは Android/iOS 専用。Web では google_mlkit_text_recognition を使わない。
// 関連: extraction_service.dart, image_file_service.dart, add_todo_screen.dart

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrException implements Exception {
  const OcrException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class OcrService {
  OcrService();

  Future<String> recognize(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    try {
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text.trim();
    } on PlatformException catch (e) {
      throw OcrException(_messageForPlatformException(e), cause: e);
    } finally {
      await recognizer.close();
    }
  }

  String _messageForPlatformException(PlatformException e) {
    final raw = '${e.message ?? ''}\n${e.details ?? ''}';
    if (raw.contains('NullPointerException') || raw.contains('getClass()')) {
      return '日本語OCRの初期化に失敗しました。Androidの日本語OCR言語パックがAPKに入っていない、または古いAPKを実行している可能性があります。最新コードで flutter clean → flutter pub get → flutter run を実行し直してください。';
    }
    return 'OCRの読み取りに失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。';
  }
}
