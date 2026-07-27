import 'package:ashita_motsumono/src/services/document_intake_service.dart';
import 'package:ashita_motsumono/src/widgets/intake_progress_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows progress and invokes cooperative cancellation', (
    tester,
  ) async {
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: IntakeProgressOverlay(
          progress: const IntakeProgress(
            stage: IntakeProgressStage.recognizingPdf,
            current: 3,
            total: 8,
          ),
          onCancel: () => cancelled = true,
        ),
      ),
    );

    expect(find.text('3/8ページを読み取り中'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    expect(cancelled, isTrue);
  });

  testWidgets('disables cooperative cancellation while saving', (tester) async {
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: IntakeProgressOverlay(
          progress: const IntakeProgress(
            stage: IntakeProgressStage.saving,
            current: 1,
            total: 1,
          ),
          onCancel: () => cancelled = true,
        ),
      ),
    );

    expect(find.text('読み取り結果を保存中...'), findsOneWidget);
    expect(find.text('保存中はキャンセルできません。'), findsOneWidget);
    expect(find.text('保存中'), findsOneWidget);

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(cancelled, isFalse);
  });
}
