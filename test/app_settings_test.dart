// test/app_settings_test.dart
// AppSettings のユーザー学習辞書保存を検証する。
// 関連: lib/src/services/app_settings.dart

import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'adds learned item labels with trimming, dedupe and empty filtering',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance());

      await settings.addLearnedItemLabels([' 軍手 ', '', '水筒', '軍手']);

      expect(settings.learnedItemLabels, ['軍手', '水筒']);
    },
  );
}
