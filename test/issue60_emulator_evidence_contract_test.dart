import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('tool/issue60_emulator_evidence.ps1');
  final core = File('tool/issue60_emulator_evidence_core.ps1');
  final cases = File('tool/issue60_emulator_evidence_cases.ps1');
  final runbook = File('docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md');
  final checklist = File('docs/notification-release-checklist.md');
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  String readTool() => <File>[script, core, cases]
      .map((file) => file.readAsStringSync())
      .join('\n');

  test('Issue #60 evidence files exist', () {
    for (final file in <File>[script, core, cases, runbook, checklist]) {
      expect(file.existsSync(), isTrue, reason: file.path);
    }
  });

  test('PowerShell entrypoint fixes target identity and workflow', () {
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
    expect(text, contains('issue60_emulator_evidence_core.ps1'));
    expect(text, contains('issue60_emulator_evidence_cases.ps1'));
  });

  test('all ADB execution uses the fixed serial wrapper', () {
    final text = readTool();

    expect(text, contains(r'& adb -s $Serial @Args'));
    expect('& adb '.allMatches(text).length, 2);
  });

  test('PowerShell tool implements evidence and verdict gates', () {
    final text = readTool();

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
    final text = readTool().toLowerCase();

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
