import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('tool/issue60_emulator_evidence.ps1');
  final core = File('tool/issue60_emulator_evidence_core.ps1');
  final cases = File('tool/issue60_emulator_evidence_cases.ps1');
  final sessionDriver = File('tool/release_validation_session.ps1');
  final runbook = File('docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md');
  final sessionRunbook = File('docs/RELEASE_VALIDATION_SESSION.md');
  final releasePlan = File('docs/RELEASE_EXECUTION_PLAN.md');
  final checklist = File('docs/notification-release-checklist.md');
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  String readEvidenceTool() => <File>[script, core, cases]
      .map((file) => file.readAsStringSync())
      .join('\n');

  String readAllPowerShell() => <File>[
        script,
        core,
        cases,
        sessionDriver,
      ].map((file) => file.readAsStringSync()).join('\n');

  test('Issue #60 evidence and session files exist', () {
    for (final file in <File>[
      script,
      core,
      cases,
      sessionDriver,
      runbook,
      sessionRunbook,
      releasePlan,
      checklist,
    ]) {
      expect(file.existsSync(), isTrue, reason: file.path);
    }
  });

  test('PowerShell entrypoint fixes target identity and workflow', () {
    final text = script.readAsStringSync();

    expect(text, contains("'emulator-5554'"));
    expect(text, contains("'com.ashita_motsumono'"));
    expect(text, contains("'PlanCase'"));
    expect(text, contains("'BeginCase'"));
    expect(text, contains("'Aggregate'"));
    expect(text, contains(r'$Serial -ne'));
    expect(text, contains(r'$PackageName -ne'));
    expect(text, contains('issue60_emulator_evidence_core.ps1'));
    expect(text, contains('issue60_emulator_evidence_cases.ps1'));
  });

  test('all direct ADB execution stays in the fixed serial wrapper', () {
    final text = readAllPowerShell();

    expect(text, contains(r'& adb -s $Serial @Args'));
    expect('& adb '.allMatches(text).length, 2);
  });

  test('evidence tool proves alarm registration with a pre-save delta', () {
    final entrypoint = script.readAsStringSync();
    final coreText = core.readAsStringSync();
    final casesText = cases.readAsStringSync();

    expect(entrypoint, contains("Snapshot 'pre-save'"));
    expect(entrypoint, contains('case-plan.json'));
    expect(entrypoint, contains('AlarmRegistration'));
    expect(entrypoint, contains('alarm-registration.json'));
    expect(coreText, contains('function RelevantAlarmLines'));
    expect(coreText, contains('function AlarmRegistration'));
    expect(coreText, contains('BeforeRelevantLineCount'));
    expect(coreText, contains('AfterRelevantLineCount'));
    expect(coreText, contains('AddedLineCount'));
    expect(coreText, contains('AddedLines'));
    expect(
      casesText,
      contains("\\$r.Result -eq 'PASS' -and [int]\\$r.AddedLineCount -gt 0"),
    );
    expect(casesText, contains('AlarmRegistrationEvidence'));
  });

  test('PowerShell tool implements evidence and verdict gates', () {
    final text = readEvidenceTool();

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
      'InstallBroadcastVerified',
      'InstallBroadcastUnverified',
      'NotificationEvidenceComplete',
      'SourceConsistency',
      'CurrentSourceMatches',
      'case-result.json',
      'issue-comment.md',
      'issue60-summary.md',
      'ELIGIBLE_FOR_CLOSE_REVIEW',
    ]) {
      expect(text, contains(required), reason: 'missing contract token: $required');
    }
  });

  test('install close path requires notification evidence and source consistency', () {
    final text = cases.readAsStringSync();

    expect(
      text,
      contains("if(-not \\$notificationComplete -or -not \\$installResult"),
    );
    expect(
      text,
      contains("\\$i.Verdict -eq 'PASS' -and \\$i.InstallBroadcastVerified"),
    );
    expect(text, contains(r'$sourceConsistent'));
    expect(text, contains(r'$currentSourceMatches'));
  });

  test('session driver has one evidence root and strict execution order', () {
    final text = sessionDriver.readAsStringSync();

    for (final required in <String>[
      'ashita-release-evidence',
      'release-validation-state.json',
      'release-session.json',
      'release_execution_orchestrator.py',
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
      'normal case must PASS before reboot',
      'reboot case must PASS before install-r',
      "git fetch origin",
      'Permission',
      'GRANTED',
      'host UTC offset must be +09:00',
    ]) {
      expect(text, contains(required), reason: 'missing session token: $required');
    }

    final doctor = text.indexOf("'Doctor'");
    final buildInstall = text.indexOf("'BuildInstall'");
    final startSession = text.indexOf("'StartSession'");
    final planCase = text.indexOf("'PlanCase'");
    final aggregate = text.indexOf("'Aggregate'");
    expect(
      <int>[doctor, buildInstall, startSession, planCase, aggregate],
      orderedEquals(
        <int>[doctor, buildInstall, startSession, planCase, aggregate]..sort(),
      ),
    );
  });

  test('PowerShell tools exclude prohibited ADB and data-reset operations', () {
    final text = readAllPowerShell().toLowerCase();

    for (final prohibited in <String>[
      'force-stop',
      'pm clear',
      'adb -d',
      'adb uninstall',
      'wipe-data',
    ]) {
      expect(text, isNot(contains(prohibited)), reason: prohibited);
    }
  });

  test('PowerShell files parse when a shell is available', () {
    String? shell;
    for (final candidate in <String>[
      'pwsh',
      if (Platform.isWindows) 'powershell',
    ]) {
      try {
        final probe = Process.runSync(
          candidate,
          <String>[
            '-NoLogo',
            '-NoProfile',
            '-Command',
            r'$PSVersionTable.PSVersion.ToString()',
          ],
        );
        if (probe.exitCode == 0) {
          shell = candidate;
          break;
        }
      } on ProcessException {
        continue;
      }
    }

    if (shell == null) {
      if (Platform.environment['CI'] == 'true') {
        fail('PowerShell is required in CI to parse release validation tools.');
      }
      return;
    }

    final parserScript = r'''
$failed = $false
$files = @(
  Get-ChildItem tool/issue60_emulator_evidence*.ps1
  Get-Item tool/release_validation_session.ps1
)
$files | ForEach-Object {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $_.FullName,
    [ref]$tokens,
    [ref]$errors
  ) | Out-Null
  if ($errors.Count -gt 0) {
    foreach ($parseError in $errors) {
      Write-Error ("{0}:{1}:{2}: {3}" -f $_.Name, $parseError.Extent.StartLineNumber, $parseError.Extent.StartColumnNumber, $parseError.Message)
    }
    $failed = $true
  }
}
if ($failed) { exit 1 }
''';
    final result = Process.runSync(
      shell,
      <String>['-NoLogo', '-NoProfile', '-Command', parserScript],
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });

  test('runbooks preserve session, case, and release acceptance order', () {
    final issueText = runbook.readAsStringSync();
    final sessionText = sessionRunbook.readAsStringSync();
    final releaseText = releasePlan.readAsStringSync();
    final checklistText = checklist.readAsStringSync();

    for (final token in <String>[
      'Todo作成前',
      'alarm-registration.json',
      'AddedLineCount > 0',
      '通常通知がPASSしてから進み',
      'boot ID',
      'MY_PACKAGE_REPLACED',
      'InstallBroadcastVerified',
      'INCONCLUSIVE',
      'Source SHA',
      'Aggregate',
    ]) {
      expect(issueText, contains(token), reason: token);
    }

    final doctor = sessionText.indexOf('## 3. GO/NO-GO診断');
    final install = sessionText.indexOf('## 4. APKビルドと初期インストール');
    final start = sessionText.indexOf('## 5. Release session開始');
    final normal = sessionText.indexOf('## 6. Normalケース');
    final reboot = sessionText.indexOf('## 7. Rebootケース');
    final update = sessionText.indexOf('## 8. install-rケース');
    final aggregate = sessionText.indexOf('## 9. Issue #60集約');
    expect(
      <int>[doctor, install, start, normal, reboot, update, aggregate],
      orderedEquals(
        <int>[doctor, install, start, normal, reboot, update, aggregate]..sort(),
      ),
    );

    expect(releaseText, contains('Documents\\ashita-release-evidence'));
    expect(releaseText, contains('release_validation_session.ps1'));
    expect(releaseText, contains('Todo作成前後のAlarm登録差分'));
    expect(checklistText, contains('予定時刻+20分'));
    expect(checklistText, contains('Alarm登録差分'));
    expect(checklistText, contains('NormalがPASS'));
    expect(checklistText, contains('RebootがPASS'));
    expect(checklistText, contains('3ケースのSource SHA'));
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
