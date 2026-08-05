// test/learned_dictionary_screen_test.dart
// 読み取り辞書の個別削除・取り消し・全消去を検証する。

import 'package:ashita_motsumono/src/screens/learned_dictionary_screen.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppSettings> _settingsWithLabels(List<String> labels) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings(await SharedPreferences.getInstance());
  await settings.addLearnedItemLabels(labels);
  return settings;
}

void main() {
  testWidgets('removes one learned label and restores it from snackbar', (
    tester,
  ) async {
    final settings = await _settingsWithLabels(['軍手', '水筒']);
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LearnedDictionaryScreen(settings: settings)),
    );

    expect(find.text('学習済み 2件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove-learned-label-水筒')));
    await tester.pumpAndSettle();

    expect(settings.learnedItemLabels, ['軍手']);
    expect(find.byKey(const ValueKey('learned-label-水筒')), findsNothing);
    expect(find.text('元に戻す'), findsOneWidget);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(settings.learnedItemLabels, ['水筒', '軍手']);
    expect(find.byKey(const ValueKey('learned-label-水筒')), findsOneWidget);
  });

  testWidgets('clears every learned label after confirmation', (tester) async {
    final settings = await _settingsWithLabels(['軍手', '水筒']);
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LearnedDictionaryScreen(settings: settings)),
    );

    await tester.tap(find.byKey(const ValueKey('clear-learned-dictionary')));
    await tester.pumpAndSettle();
    expect(find.text('読み取り辞書をすべて削除'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'すべて削除'));
    await tester.pumpAndSettle();

    expect(settings.learnedItemLabels, isEmpty);
    expect(find.text('学習した語はまだありません'), findsOneWidget);
  });
}
