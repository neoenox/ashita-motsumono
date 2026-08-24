import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native OCR closes the recognizer inside onComplete', () {
    final source = File(
      'android/app/src/main/kotlin/com/ashita_motsumono/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('.addOnCompleteListener'));
    expect(
      source,
      contains(
        RegExp(r'addOnCompleteListener \{ task ->\s*recognizer\.close\(\)'),
      ),
    );
  });

  test('Android OCR invocation is bounded by a timeout on the Dart side', () {
    final source = File('lib/src/services/ocr_service.dart').readAsStringSync();

    expect(
      source,
      contains('static const defaultTimeout = Duration(seconds: 60);'),
    );
    expect(source, contains('.timeout(timeout)'));
    expect(source, contains('on TimeoutException catch (e)'));
  });
}
