import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final readme = File('docs/validation/android-notifications/README.md');
  final environment = File(
    'docs/validation/android-notifications/environment.md',
  );
  final testEvidence = File(
    'docs/validation/android-notifications/logs/flutter-test.txt',
  );

  test(
    'notification validation evidence uses concrete immutable references',
    () {
      for (final file in <File>[readme, environment, testEvidence]) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }

      final readmeText = readme.readAsStringSync();
      final environmentText = environment.readAsStringSync();
      final combined = '$readmeText\n$environmentText';

      expect(combined, contains('d40f591745051ad6feab82a86221eb0d648d7ead'));
      expect(combined, contains('bd261d53e13e2585f1cfb3e521589666e2f3051f'));
      expect(combined, contains('29298500627'));
      expect(combined, contains('Flutter CI #754'));
      expect(combined, isNot(contains('本文末尾参照')));
      expect(combined, isNot(contains('コミット後に再取得')));
      expect(combined, isNot(contains('テスト・format実行時点のSHA')));
    },
  );

  test(
    'committed test evidence does not retain the superseded plugin error',
    () {
      final text = testEvidence.readAsStringSync();

      expect(text, contains('Superseded evidence notice'));
      expect(text, contains('analyze-and-test: SUCCESS'));
      expect(text, contains('Test step: SUCCESS'));
      expect(text, isNot(contains('LateInitializationError')));
      expect(text, isNot(contains('C:\\Users\\')));
      expect(text, isNot(contains('/home/')));
    },
  );
}
