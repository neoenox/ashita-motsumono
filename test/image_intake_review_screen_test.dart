// test/image_intake_review_screen_test.dart
// 複数画像の順番確認・除外画面をWidget testで検証する。

import 'package:ashita_motsumono/src/screens/image_intake_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('shows selected pages and removes excluded images', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageIntakeReviewScreen(
          files: [
            XFile('/tmp/front.jpg'),
            XFile('/tmp/back.jpg'),
            XFile('/tmp/notice.jpg'),
          ],
        ),
      ),
    );

    expect(find.text('画像の順番を確認'), findsOneWidget);
    expect(find.text('front.jpg'), findsOneWidget);
    expect(find.text('back.jpg'), findsOneWidget);
    expect(find.text('notice.jpg'), findsOneWidget);
    expect(find.text('この順番で3枚を読み取る'), findsOneWidget);

    await tester.tap(find.byTooltip('この画像を除外').at(1));
    await tester.pumpAndSettle();

    expect(find.text('back.jpg'), findsNothing);
    expect(find.text('この順番で2枚を読み取る'), findsOneWidget);
  });

  testWidgets('disables confirmation after every image is excluded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageIntakeReviewScreen(files: [XFile('/tmp/only.jpg')]),
      ),
    );

    await tester.tap(find.byTooltip('この画像を除外'));
    await tester.pumpAndSettle();

    expect(find.text('読み取る画像がありません'), findsOneWidget);
    expect(find.text('画像を選び直してください'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-image-intake-order')),
    );
    expect(button.onPressed, isNull);
  });
}
