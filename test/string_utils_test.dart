// test/string_utils_test.dart
// splitItems の分割ロジックをテストする。
// 関連: lib/src/utils/string_utils.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/utils/string_utils.dart';

void main() {
  group('splitItems', () {
    test('splits by comma', () {
      expect(splitItems('水筒,タオル,帽子'), ['水筒', 'タオル', '帽子']);
    });

    test('splits by Japanese comma', () {
      expect(splitItems('水筒、タオル、帽子'), ['水筒', 'タオル', '帽子']);
    });

    test('splits by newline', () {
      expect(splitItems('水筒\nタオル\n帽子'), ['水筒', 'タオル', '帽子']);
    });

    test('trims whitespace', () {
      expect(splitItems(' 水筒 , タオル '), ['水筒', 'タオル']);
    });

    test('filters empty entries', () {
      expect(splitItems('水筒,,タオル'), ['水筒', 'タオル']);
    });

    test('returns empty list for empty input', () {
      expect(splitItems(''), []);
    });
  });
}
