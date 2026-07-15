import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final entrypoint = File('tool/issue60_emulator_evidence.ps1');
  final core = File('tool/issue60_emulator_evidence_core.ps1');
  final cases = File('tool/issue60_emulator_evidence_cases.ps1');
  final sessionDriver = File('tool/release_validation_session.ps1');
  final issueRunbook = File('docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md');
  final sessionRunbook = File('docs/RELEASE_VALIDATION_SESSION.md');
  final releasePlan = File('docs/RELEASE_EXECUTION_PLAN.md');
  final checklist = File('docs/notification-release-checklist.md');
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  final evidenceFiles = <File>[entrypoint, core, cases];
  final powerShellFiles = <File>[...evidenceFiles, sessionDriver];

  String joinFiles(Iterable<File> files) =>
      files.map((file) => file.readAsStringSync()).join('\n');

  test('Issue #60 evidence and session files exist', () {
    for (final file in <File>[
      ...powerShellFiles,
      issueRunbook,
      sessionRunbook,
      releasePlan,
      checklist,
    ]) {
      expect(file.existsSync(), isTrue, reason: file.path);
    }
  });

  test('entrypoint fixes target identity and workflow actions', () {
    final text = entrypoint.readAsStringSync();

    for (final token in <String>[
      "'emulator-5554'",
      "'com.ashita_motsumono'",
      "'PlanCase'",
      "'BeginCase'",
      "'Aggregate'",
      r'$Serial -ne',
      r'$PackageName -ne',
      'issue60_emulator_evidence_core.ps1',
      'issue60_emulator_evidence_cases.ps1',
    ]) {
      expect(text, contains(token), reason: token);
    }
  });

  test('all direct ADB execution stays in the fixed serial wrapper', () {
    final text = joinFiles(powerShellFiles);

    expect(text, contains(r'& adb -s $Serial @Args'));
    expect('& adb '.allMatches(text).length, 2);
  });

  test('alarm registration uses Todo pre-save and post-save evidence', () {
    final entrypointText = entrypoint.readAsStringSync();
    final coreText = core.readAsStringSync();
    final casesText = cases.readAsStringSync();
    final evidenceText = joinFiles(evidenceFiles);

    expect(entrypointText, contains("Snapshot 'pre-save'"));
    expect(evidenceText, contains('case-plan.json'));
    expect(entrypointText, contains('AlarmRegistration'));
    expect(evidenceText, contains('alarm-registration.json'));

    for (final token in <String>[
      'function RelevantAlarmLines',
      'function AlarmRegistration',
      'BeforeRelevantLineCount',
      'AfterRelevantLineCount',
      'AddedLineCount',
      'AddedLines',
    ]) {
      expect(coreText, contains(token), reason: token);
    }
    expect(
      casesText,
      contains(r"$r.Result -eq 'PASS' -and [int]$r.AddedLineCount -gt 0"),
    );
    expect(casesText, contains('AlarmRegistrationEvidence'));
  });

  test('evidence tool implements strict verdict gates', () {
    final text = joinFiles(evidenceFiles);

    for (final token in <String>[
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
      expect(text, contains(token), reason: token);
    }
  });

  test('install close path requires notification and source evidence', () {
    final text = cases.readAsStringSync();

    expect(
      text,
      contains(r'if(-not $notificationComplete -or -not $installResult'),
    );
    expect(text, contains(r'$installEligible'));
    expect(
      text,
      contains(r"$install.Verdict -eq 'PASS' -and"),
    );
    expect(text, contains(r'$install.InstallBroadcastVerified'));
    expect(
      text,
      contains(r"$install.Verdict -eq 'INCONCLUSIVE' -and"),
    );
    expect(text, contains(r'$install.InstallBroadcastUnverified'));
    expect(text, contains(r'$sourceConsistent'));
    expect(text, contains(r'$currentSourceMatches'));
  });

  test('session driver has one evidence root and strict order', () {
    final text = sessionDriver.readAsStringSync();

    for (final token in <String>[
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
      "'fetch', 'origin'",
      'GRANTED',
      'host UTC offset must be +09:00',
    ]) {
      expect(text, contains(token), reason: token);
    }

    final positions = <int>[
      text.indexOf("'Doctor'"),
      text.indexOf("'BuildInstall'"),
      text.indexOf("'StartSession'"),
      text.indexOf("'PlanCase'"),
      text.indexOf("'Aggregate'"),
    ];
    expect(positions, everyElement(greaterThanOrEqualTo(0)));
    expect(positions, orderedEquals(<int>[...positions]..sort()));
  });

  test('PowerShell excludes destructive or ambiguous ADB operations', () {
    final text = joinFiles(powerShellFiles).toLowerCase();

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

  test('runbooks preserve session and acceptance order', () {
    final issueText = issueRunbook.readAsStringSync();
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

    final positions = <int>[
      sessionText.indexOf('## 3. GO/NO-GO診断'),
      sessionText.indexOf('## 4. APKビルドと初期インストール'),
      sessionText.indexOf('## 5. Release session開始'),
      sessionText.indexOf('## 6. Normalケース'),
      sessionText.indexOf('## 7. Rebootケース'),
      sessionText.indexOf('## 8. install-rケース'),
      sessionText.indexOf('## 9. Issue #60集約'),
    ];
    expect(positions, everyElement(greaterThanOrEqualTo(0)));
    expect(positions, orderedEquals(<int>[...positions]..sort()));

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
