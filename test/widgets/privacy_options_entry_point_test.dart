import 'package:ashita_motsumono/src/services/consent_service.dart';
import 'package:ashita_motsumono/src/widgets/privacy_options_entry_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  addTearDown(() {
    ConsentService.privacyOptionsRequired.value = false;
  });

  testWidgets('hides privacy options when UMP does not require them', (
    tester,
  ) async {
    ConsentService.privacyOptionsRequired.value = false;

    await tester.pumpWidget(const _TestApp());

    expect(find.text('広告のプライバシー設定'), findsNothing);
  });

  testWidgets('shows privacy options in settings when UMP requires them', (
    tester,
  ) async {
    ConsentService.privacyOptionsRequired.value = true;

    await tester.pumpWidget(const _TestApp());

    expect(find.text('広告のプライバシー設定'), findsOneWidget);
    expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: ListView(children: [PrivacyOptionsListTile()]),
      ),
    );
  }
}
