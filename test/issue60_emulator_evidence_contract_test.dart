import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('tool/issue60_emulator_evidence.ps1');
  final runbook = File('docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md');
  final checklist = File('docs/notification-release-checklist.md');
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('Issue #60 evidence files exist', () {
    expect(script.existsSync(), isTrue);
    expect(runbook.existsSync(), isTrue);
    expect(checklist.existsSync(), isTrue);
  });

  test('PowerShell tool fixes target identity and supports full workflow', () {
    final text = script.readAsStringSync();

    expect(text, contains("'emulator-5554'"));
    expect(text, contains("'com.ashita_motsumono'"));
    expect(
      text,
      contains(
        "[ValidateSet('Preflight','BeginCase','Wait','Capture','Install','Reboot','Finalize','Aggregate')]",
      ),
    );
    expect(text, contains(r'$Serial -ne'));
    expect(text, contains(r'$PackageName -ne'));
    expect(text, contains(r'& adb -s $Serial @Args'));
    expect('& adb '.allMatches(text).length, 2);
  });

  test('PowerShell tool implements evidence and verdict gates', () {
    final text = script.readAsStringSync();

    for (final required in <String>[
      'POST_NOTIFICATION',
      'origin/master',
      'TrackedStatus',
      'expand-notifications',
      'uiautomator',
      'boot_id',
      'Get-FileHash',
      'lastUpdateTime',
      'FailureWaitMinutes',
      'wait-heartbeats.jsonl',
      'HostGapDetected',
      'TitleEvidence',
      'AppForeground',
      'case-result.json',
      'issue-comment.md',
      'issue60-summary.md',
      'ELIGIBLE_FOR_CLOSE_REVIEW',
    ]) {
      expect(text, contains(required), reason: 'missing contract token: $required');
    }
  });

  test('PowerShell tool excludes prohibited ADB operations', () {
    final text = script.readAsStringSync().toLowerCase();

    for (final prohibited in <String>[
      'force' '-stop',
      'pm' ' clear',
      'adb' ' -d',
      'adb' ' uninstall',
    ]) {
      expect(text, isNot(contains(prohibited)), reason: prohibited);
    }
  });

  test('Runbook and checklist preserve acceptance order', () {
    final runbookText = runbook.readAsStringSync();
    final checklistText = checklist.readAsStringSync();

    expect(runbookText, contains('通常通知がPASSしてから進む'));
    expect(runbookText, contains('boot ID'));
    expect(runbookText, contains('MY_PACKAGE_REPLACED'));
    expect(runbookText, contains('INCONCLUSIVE'));
    expect(runbookText, contains('Aggregate'));
    expect(checklistText, contains('予定時刻+20分'));
    expect(checklistText, contains('NormalがPASS'));
    expect(checklistText, contains('RebootがPASS'));
  });

  test('Boot receiver remains non-exported', () {
    final text = manifest.readAsStringSync();
    final receiverPattern = RegExp(
      r'<receiver\s+android:name="com\.dexterous\.flutterlocalnotifications\.ScheduledNotificationBootReceiver"\s+android:exported="false">',
      multiLine: true,
    );

    expect(text, matches(receiverPattern));
    expect(text, contains('android.intent.action.BOOT_COMPLETED'));
    expect(text, contains('android.intent.action.MY_PACKAGE_REPLACED'));
  });
}
