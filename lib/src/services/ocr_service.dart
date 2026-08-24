// lib/src/services/ocr_service.dart
// Google ML Kit Text Recognition を使って画像から日本語テキストを認識する。
// Androidではpluginの詳細構造シリアライズを避け、ネイティブ側で全文だけ返す。
// iOSでは google_mlkit_text_recognition を使う。
// 関連: extraction_service.dart, image_file_service.dart, add_todo_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  OcrService({Duration? timeout}) : timeout = timeout ?? defaultTimeout;

  /// ネイティブOCRが応答しない場合でもUIが永久待機にならないための上限。
  static const defaultTimeout = Duration(seconds: 60);

  final Duration timeout;

  static const _androidOcrChannel = MethodChannel(
    'ashita_motsumono/native_ocr',
  );

  Future<String> recognize(File imageFile) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw OcrException('OCRはAndroid/iOS専用です。Windowsではテキスト貼り付けを使ってください。');
    }

    if (!await imageFile.exists()) {
      throw StateError('画像ファイルが見つかりません: ${imageFile.path}');
    }
    final size = await imageFile.length();
    if (size == 0) {
      throw StateError('画像ファイルが空です: ${imageFile.path}');
    }
    if (kDebugMode) debugPrint('OCR: file=${imageFile.path}, size=$size');

    if (Platform.isAndroid) {
      return _recognizeOnAndroid(imageFile);
    }
    return _recognizeWithPlugin(imageFile);
  }

  Future<String> _recognizeOnAndroid(File imageFile) async {
    try {
      final text = await _androidOcrChannel
          .invokeMethod<String>(
            'recognizeJapaneseText',
            {'path': imageFile.path},
          )
          .timeout(timeout);
      return (text ?? '').trim();
    } on TimeoutException catch (e) {
      throw OcrException(
        '文字の読み取りがタイムアウトしました。もう一度お試しください。',
        cause: e,
      );
    } on PlatformException catch (e) {
      throw OcrException(_messageForPlatformException(e), cause: e);
    } on MissingPluginException catch (e) {
      throw OcrException(
        'Android OCRのネイティブ処理が見つかりません。最新コードを取得後、flutter clean → flutter pub get → flutter run を実行し直してください。',
        cause: e,
      );
    }
  }

  Future<String> _recognizeWithPlugin(File imageFile) async {
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
    final raw = '${e.code}\n${e.message ?? ''}\n${e.details ?? ''}';
    if (raw.contains('NullPointerException') || raw.contains('getClass()')) {
      return '日本語OCRの内部処理で失敗しました。最新コードで flutter clean → flutter pub get → flutter run を実行し直してください。';
    }
    if (raw.contains('JapaneseTextRecognizerOptions') ||
        raw.contains('text-recognition-japanese')) {
      return '日本語OCRの初期化に失敗しました。Androidの日本語OCR言語パックがAPKに入っていない可能性があります。';
    }
    return 'OCRの読み取りに失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。';
  }
}
