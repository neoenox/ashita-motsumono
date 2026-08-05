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

  test('removes one learned item label and persists the remaining labels', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);

    await settings.addLearnedItemLabels(['軍手', '水筒', '体操着']);
    await settings.removeLearnedItemLabel(' 水筒 ');

    expect(settings.learnedItemLabels, ['軍手', '体操着']);
    expect(prefs.getStringList('learned_item_labels_v1'), ['軍手', '体操着']);
  });

  test('ignores removal of unknown or empty learned labels', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());

    await settings.addLearnedItemLabels(['軍手']);
    await settings.removeLearnedItemLabel('');
    await settings.removeLearnedItemLabel('水筒');

    expect(settings.learnedItemLabels, ['軍手']);
  });

  test('clears learned item labels without changing purchase state', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());

    await settings.addLearnedItemLabels(['軍手', '水筒']);
    await settings.setAdRemoved(true);
    await settings.clearLearnedItemLabels();

    expect(settings.learnedItemLabels, isEmpty);
    expect(settings.adRemoved, isTrue);
  });
}
