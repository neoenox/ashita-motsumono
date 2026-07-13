import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final control = File('tool/release_validation_control.ps1');
  final alarmParser = File('tool/issue60_alarm_time_evidence.ps1');
  final backend = File('tool/release_validation_session.ps1');
  final workflow = File(
    '.github/workflows/release-validation-windows-powershell51.yml',
  );
  final runbook = File('docs/RELEASE_VALIDATION_CONTROL.md');

  test('hardening files exist', () {
    for (final file in <File>[
      control,
      alarmParser,
      backend,
      workflow,
      runbook,
    ]) {
      expect(file.existsSync(), isTrue, reason: file.path);
    }
  });

  test('control delegates existing session behavior and adds safe actions', () {
    final text = control.readAsStringSync();
    for (final token in <String>[
      'release_validation_session.ps1',
      'issue60_alarm_time_evidence.ps1',
      "'ArchiveSession'",
      "'Doctor'",
      "'BuildInstall'",
      "'StartSession'",
      "'PlanCase'",
      "'BeginCase'",
      "'MutateCase'",
      "'WaitCase'",
      "'FinalizeCase'",
      "'Aggregate'",
      "'WriteTemplates'",
      "'Evaluate'",
      "'Status'",
      'ForceArchiveActive',
      'archive-manifest.json',
      'Assert-AlarmTimingGate',
      'ExpectedTimeMatch',
      'INCONCLUSIVE',
    ]) {
      expect(text, contains(token), reason: token);
    }
  });

  test('Status exposes actionable evidence and exact next step fields', () {
    final text = control.readAsStringSync();
    for (final token in <String>[
      'doctorPassed',
      'apkInstalled',
      'notificationPermission',
      'sessionSourceSha',
      'alarmExpectedTimeMatch',
      'evidenceFiles',
      'nextAction',
      'nextCommand',
      'manualAction',
      'release-validation-status.json',
    ]) {
      expect(text, contains(token), reason: token);
    }
  });

  test('Alarm parser is conservative and time bounded', () {
    final text = alarmParser.readAsStringSync();
    for (final token in <String>[
      'ToleranceMinutes',
      'addedCandidates',
      'matchingCandidates',
      "'PASS'",
      "'MISMATCH'",
      "'INCONCLUSIVE'",
      'unparseablePolicy',
      'mismatchPolicy',
      'ScheduledNotificationReceiver',
      'flutterlocalnotifications',
      'com.ashita_motsumono',
    ]) {
      expect(text, contains(token), reason: token);
    }
    expect(text, contains(r'$ToleranceMinutes * 60 * 1000'));
  });

  test('Windows PowerShell 5.1 CI validates runtime behavior', () {
    final text = workflow.readAsStringSync();
    for (final token in <String>[
      'windows-latest',
      'shell: powershell',
      'Windows PowerShell 5.1',
      'UTF-8 BOM must not be present',
      'missing git must produce UNKNOWN',
      'expected PASS',
      'expected MISMATCH',
      'unparseable alarm must be INCONCLUSIVE',
      'active session archive must require ForceArchiveActive',
      'archive-manifest.json',
    ]) {
      expect(text, contains(token), reason: token);
    }
  });

  test('control plane preserves fixed target and prohibited operations', () {
    final text = '${control.readAsStringSync()}\n'
        '${alarmParser.readAsStringSync()}'.toLowerCase();
    expect(text, contains('emulator-5554'));
    expect(text, contains('com.ashita_motsumono'));
    for (final token in <String>[
      'force-stop',
      'pm clear',
      'adb -d',
      'adb uninstall',
      'wipe-data',
    ]) {
      expect(text, isNot(contains(token)), reason: token);
    }
  });

  test('runbook makes hardened control authoritative', () {
    final text = runbook.readAsStringSync();
    for (final token in <String>[
      'release_validation_control.ps1',
      'ArchiveSession',
      'ForceArchiveActive',
      'ExpectedTimeMatch=PASS',
      'Windows PowerShell 5.1',
      'Normal',
      'Reboot',
      'install-r',
      'INCONCLUSIVE',
      'Status',
      'nextCommand',
      'Issue #60',
      'Issue #98',
      'Issue #59',
      'Issue #94',
    ]) {
      expect(text, contains(token), reason: token);
    }
  });
}
