function PlanPath {
  Join-Path $CaseDirectory 'case-plan.json'
}

function Plan {
  if (-not (Test-Path (PlanPath))) {
    throw 'PlanCase required'
  }
  Get-Content -Raw -Encoding utf8 (PlanPath) | ConvertFrom-Json
}

function MetadataPath {
  Join-Path $CaseDirectory 'case-metadata.json'
}

function Metadata {
  if (-not (Test-Path (MetadataPath))) {
    throw 'BeginCase required'
  }
  Get-Content -Raw -Encoding utf8 (MetadataPath) | ConvertFrom-Json
}

function AssertPlan {
  $p = Plan
  if ([string]$p.CaseType -ne $CaseType) {
    throw 'CaseType mismatch'
  }
  if ($TodoTitle -and [string]$p.TodoTitle -ne $TodoTitle) {
    throw 'TodoTitle mismatch'
  }
  if (
    $ExpectedTime -and
    (ParseTime $ExpectedTime 'ExpectedTime') -ne
      (ParseTime ([string]$p.ExpectedTime) 'plan.ExpectedTime')
  ) {
    throw 'ExpectedTime mismatch'
  }
  $p
}

function AssertCase {
  $m = Metadata
  if ([string]$m.CaseType -ne $CaseType) {
    throw 'CaseType mismatch'
  }
  if ($TodoTitle -and [string]$m.TodoTitle -ne $TodoTitle) {
    throw 'TodoTitle mismatch'
  }
  if (
    $ExpectedTime -and
    (ParseTime $ExpectedTime 'ExpectedTime') -ne
      (ParseTime ([string]$m.ExpectedTime) 'metadata.ExpectedTime')
  ) {
    throw 'ExpectedTime mismatch'
  }
  $m
}

function LatestSummary {
  $files = Get-ChildItem `
    $CaseDirectory `
    -Filter snapshot-summary.json `
    -Recurse `
    -File |
    Sort-Object LastWriteTime
  if (-not $files) {
    return $null
  }
  Get-Content -Raw -Encoding utf8 $files[-1].FullName |
    ConvertFrom-Json
}

function AlarmEvidence {
  $path = Join-Path $CaseDirectory 'alarm-registration.json'
  if (-not (Test-Path $path)) {
    return $false
  }
  $r = Get-Content -Raw -Encoding utf8 $path | ConvertFrom-Json
  $timeProperty = $r.PSObject.Properties['ExpectedTimeMatch']
  [bool](
    $r.Result -eq 'PASS' -and [int]$r.AddedLineCount -gt 0 -and
    $r.RelevantLineCountIncreased -eq $true -and
    [int]$r.AfterRelevantLineCount -gt
      [int]$r.BeforeRelevantLineCount -and
    $timeProperty -and
    [string]$timeProperty.Value -eq 'PASS'
  )
}

function AlarmTimeResult {
  $path = Join-Path $CaseDirectory 'alarm-registration.json'
  if (-not (Test-Path $path)) {
    return ''
  }
  $registration = Get-Content -Raw -Encoding utf8 $path |
    ConvertFrom-Json
  $property = $registration.PSObject.Properties['ExpectedTimeMatch']
  if (-not $property) {
    return ''
  }
  [string]$property.Value
}

function WaitCase {
  $m = AssertCase
  RequirePreflight -RequireApp | Out-Null
  if (-not (AlarmEvidence)) {
    throw (
      'alarm registration and ExpectedTimeMatch must PASS before Wait'
    )
  }
  $expected = ParseTime ([string]$m.ExpectedTime) 'ExpectedTime'
  $deadline = $expected.AddMinutes($FailureWaitMinutes)
  $directory = Join-Path $CaseDirectory "$(Stamp)-wait"
  New-Item -ItemType Directory -Force $directory | Out-Null
  $heartbeatPath = Join-Path $directory 'wait-heartbeats.jsonl'
  $bootId = AdbText @(
    'shell',
    'cat',
    '/proc/sys/kernel/random/boot_id'
  )
  $last = [DateTimeOffset]::Now
  $iteration = 0

  while ($true) {
    $iteration++
    $now = [DateTimeOffset]::Now
    $gap = ($now - $last).TotalSeconds
    $last = $now
    $state = AdbText @('get-state')
    $boot = AdbText @('shell', 'getprop', 'sys.boot_completed')
    $timezone = AdbText @(
      'shell',
      'getprop',
      'persist.sys.timezone'
    )
    $permission = Permission
    $currentBootId = AdbText @(
      'shell',
      'cat',
      '/proc/sys/kernel/random/boot_id'
    )
    $foreground = Foreground
    $notification = AdbText @(
      'shell',
      'dumpsys',
      'notification',
      '--noredact'
    )
    $found = $notification -match [regex]::Escape(
      [string]$m.TodoTitle
    )
    $hostGap = (
      $iteration -gt 1 -and
      $gap -gt (($PollSeconds * 3) + 10)
    )
    $heartbeat = [ordered]@{
      Iteration = $iteration
      HostTime = $now.ToString('o')
      DeviceTime = DeviceTime
      HostGapSeconds = [math]::Round($gap, 2)
      HostGapDetected = $hostGap
      State = $state
      Boot = $boot
      Timezone = $timezone
      Permission = $permission
      BootId = $currentBootId
      BootIdUnchanged = ($currentBootId -eq $bootId)
      AppForeground = $foreground.IsApp
      TitleObserved = $found
    }
    ($heartbeat | ConvertTo-Json -Compress) |
      Out-File $heartbeatPath -Append -Encoding utf8

    if (
      $state -ne 'device' -or
      $boot -ne '1' -or
      $timezone -ne 'Asia/Tokyo' -or
      $permission -ne 'GRANTED' -or
      $currentBootId -ne $bootId -or
      $foreground.IsApp -or
      $hostGap
    ) {
      $snapshot = Snapshot 'wait-blocked'
      Json (
        [ordered]@{
          Result = 'BLOCKED'
          Heartbeat = $heartbeat
          Snapshot = $snapshot
        }
      ) (Join-Path $CaseDirectory 'wait-result.json')
      return
    }

    if ($found) {
      $snapshot = Snapshot 'notification-observed' -Shade
      Json (
        [ordered]@{
          Result = 'NOTIFICATION_OBSERVED'
          ObservedAtHost = $now.ToString('o')
          ObservedAtDevice = DeviceTime
          ExpectedTime = $expected.ToString('o')
          Snapshot = $snapshot
          AppOpenedByScript = $false
        }
      ) (Join-Path $CaseDirectory 'wait-result.json')
      return
    }

    if ($now -ge $deadline) {
      $snapshot = Snapshot 'wait-timeout' -Shade
      Json (
        [ordered]@{
          Result = 'TIMEOUT'
          Deadline = $deadline.ToString('o')
          CompletedAtHost = $now.ToString('o')
          CompletedAtDevice = DeviceTime
          Snapshot = $snapshot
          AppOpenedByScript = $false
        }
      ) (Join-Path $CaseDirectory 'wait-result.json')
      return
    }
    Start-Sleep $PollSeconds
  }
}

function NotificationEvidenceComplete(
  $Actual,
  $PermissionValue,
  $AlarmValue,
  $TitleValue,
  $VisibleValue,
  $ForegroundValue,
  $ScreenValue,
  $DumpValue,
  $GitGateValue
) {
  [bool](
    $Actual -and
    $PermissionValue -eq 'GRANTED' -and
    $AlarmValue -and
    $TitleValue -and
    $VisibleValue -and
    -not $ForegroundValue -and
    $ScreenValue -and
    $DumpValue -and
    $GitGateValue -eq 'PASS'
  )
}

function FinalizeCase {
  $m = AssertCase
  if ($Verdict -notin @(
      'PASS',
      'FAIL',
      'BLOCKED',
      'INCONCLUSIVE'
    )) {
    throw 'invalid Verdict'
  }
  $expected = ParseTime ([string]$m.ExpectedTime) 'ExpectedTime'
  $waitPath = Join-Path $CaseDirectory 'wait-result.json'
  $wait = if (Test-Path $waitPath) {
    Get-Content -Raw -Encoding utf8 $waitPath | ConvertFrom-Json
  }
  else {
    $null
  }
  $actual = $ActualArrivalTime
  if (
    -not $actual -and
    $wait -and
    $wait.Result -eq 'NOTIFICATION_OBSERVED'
  ) {
    $actual = [string]$wait.ObservedAtDevice
  }
  if ($actual) {
    ParseTime $actual 'ActualArrivalTime' | Out-Null
  }

  $summary = LatestSummary
  $alarm = AlarmEvidence
  $alarmTime = AlarmTimeResult
  $git = GitState
  $permission = if ($summary) {
    [string]$summary.Permission
  }
  else {
    Permission
  }
  $title = [bool]($summary -and $summary.TitleEvidence)
  $visible = (
    [bool]($summary -and $summary.TitleInUi) -or
    $ManualScreenshotVerified
  )
  $foreground = [bool]($summary -and $summary.AppForeground)
  $summaryFile = Get-ChildItem `
    $CaseDirectory `
    -Filter snapshot-summary.json `
    -Recurse `
    -File |
    Sort-Object LastWriteTime |
    Select-Object -Last 1
  $directory = if ($summaryFile) {
    $summaryFile.Directory.FullName
  }
  else {
    ''
  }
  $screen = [bool](
    $directory -and
    (Test-Path (Join-Path $directory 'screen.png')) -and
    (Get-Item (Join-Path $directory 'screen.png')).Length -gt 0
  )
  $dump = [bool](
    $directory -and
    (Test-Path (Join-Path $directory 'notification.txt')) -and
    (Get-Item (Join-Path $directory 'notification.txt')).Length -gt 0
  )
  $notificationComplete = NotificationEvidenceComplete `
    $actual `
    $permission `
    $alarm `
    $title `
    $visible `
    $foreground `
    $screen `
    $dump `
    $git.Gate

  $installResult = $null
  if ($CaseType -eq 'install-r') {
    $installPath = Join-Path $CaseDirectory 'install-result.json'
    if (Test-Path $installPath) {
      $installResult = Get-Content -Raw -Encoding utf8 $installPath |
        ConvertFrom-Json
    }
  }

  if ($Verdict -eq 'PASS') {
    if (-not $notificationComplete) {
      throw 'PASS evidence incomplete'
    }
    if ($alarmTime -ne 'PASS') {
      throw 'PASS requires ExpectedTimeMatch=PASS'
    }
    if ($CaseType -eq 'reboot') {
      $reboot = Get-Content `
        -Raw `
        -Encoding utf8 `
        (Join-Path $CaseDirectory 'reboot-result.json') |
        ConvertFrom-Json
      if ($reboot.Result -ne 'PASS' -or -not $reboot.BootIdChanged) {
        throw 'reboot evidence incomplete'
      }
    }
    if ($CaseType -eq 'install-r') {
      if (
        -not $installResult -or
        $installResult.Result -ne 'PASS'
      ) {
        throw 'install evidence incomplete'
      }
      if (
        -not $InstallBroadcastVerified -or
        $InstallBroadcastUnverified
      ) {
        throw (
          'install-r PASS requires verified ' +
          'MY_PACKAGE_REPLACED evidence'
        )
      }
      $reason = (
        'notification evidence complete, alarm time matched, and ' +
        'MY_PACKAGE_REPLACED evidence explicitly verified'
      )
    }
    else {
      $reason = (
        'permission, alarm registration delta, expected alarm time, ' +
        'visible title, screenshot, notification dump, foreground, ' +
        'and git gates passed'
      )
    }
  }
  elseif ($Verdict -eq 'FAIL') {
    if (
      [DateTimeOffset]::Now -lt
        $expected.AddMinutes($FailureWaitMinutes) -or
      $permission -ne 'GRANTED' -or
      -not $alarm -or
      $alarmTime -ne 'PASS' -or
      $foreground -or
      -not $screen -or
      -not $dump -or
      $git.Gate -ne 'PASS' -or
      $title -or
      -not $wait -or
      $wait.Result -ne 'TIMEOUT'
    ) {
      throw 'FAIL evidence incomplete'
    }
    $reason = (
      'wait deadline reached with valid environment, matched alarm ' +
      'time, and no notification title'
    )
  }
  elseif ($Verdict -eq 'BLOCKED') {
    $reason = 'environment conditions broke'
  }
  else {
    if (
      $CaseType -eq 'install-r' -and
      $InstallBroadcastUnverified
    ) {
      if(-not $notificationComplete -or -not $installResult -or
        $installResult.Result -ne 'PASS' -or
        $InstallBroadcastVerified) {
        throw 'install-r INCONCLUSIVE close-path evidence incomplete'
      }
      $reason = (
        'install and notification observed; ' +
        'MY_PACKAGE_REPLACED not uniquely proven'
      )
    }
    else {
      $reason = 'evidence or causality incomplete'
    }
  }

  $result = [pscustomobject][ordered]@{
    CaseName = $CaseName
    CaseType = $CaseType
    Verdict = $Verdict
    TodoTitle = [string]$m.TodoTitle
    SourceSha = [string]$m.SourceSha
    ExpectedTime = [string]$m.ExpectedTime
    ActualArrivalTime = $actual
    Permission = $permission
    AlarmRegistrationEvidence = $alarm
    AlarmExpectedTimeMatch = $alarmTime
    TitleEvidence = $title
    VisibleTitle = $visible
    AppForeground = $foreground
    Screen = $screen
    NotificationDump = $dump
    GitGate = $git.Gate
    InstallBroadcastVerified = $InstallBroadcastVerified.IsPresent
    InstallBroadcastUnverified = $InstallBroadcastUnverified.IsPresent
    Reason = $reason
    Notes = $Notes
    FinalizedAt = Get-Date -Format o
  }
  Json $result (Join-Path $CaseDirectory 'case-result.json')

  @(
    "## Issue #60 Emulator validation: $CaseName",
    '',
    "- Verdict: **$Verdict**",
    "- Todo: ``$($result.TodoTitle)``",
    "- Source SHA: ``$($result.SourceSha)``",
    "- Expected time: ``$($result.ExpectedTime)``",
    "- Arrival time: ``$($result.ActualArrivalTime)``",
    "- Alarm expected-time match: ``$alarmTime``",
    '',
    '### Confirmed facts',
    "- $reason",
    '',
    '### Unconfirmed items',
    $(if ($Verdict -eq 'INCONCLUSIVE') {
        '- Part of the evidence or causality remains unconfirmed.'
      }
      else {
        '- None.'
      }),
    '',
    '### Hypotheses',
    '- None.',
    '',
    '### Counterevidence',
    '- Static checks, build, and launch success were not treated as notification PASS.',
    '',
    '### Decision basis',
    "- $reason",
    '',
    '### Notes',
    "- $Notes"
  ) -join "`n" |
    Out-File `
      (Join-Path $CaseDirectory 'issue-comment.md') `
      -Encoding utf8
}

function Result([string]$Name, [string]$Type) {
  $path = Join-Path (
    Join-Path $OutputRoot $Name
  ) 'case-result.json'
  if (-not (Test-Path $path)) {
    throw "missing $path"
  }
  $result = Get-Content -Raw -Encoding utf8 $path |
    ConvertFrom-Json
  if ($result.CaseType -ne $Type) {
    throw 'case type mismatch'
  }
  $result
}

function Aggregate {
  if (
    -not $NormalCaseName -or
    -not $RebootCaseName -or
    -not $InstallCaseName
  ) {
    throw 'three case names required'
  }
  $normal = Result $NormalCaseName 'normal'
  $reboot = Result $RebootCaseName 'reboot'
  $install = Result $InstallCaseName 'install-r'
  $sources = @(
    $normal.SourceSha,
    $reboot.SourceSha,
    $install.SourceSha
  ) |
    Where-Object { $_ } |
    Select-Object -Unique
  $sourceConsistent = $sources.Count -eq 1
  $git = GitState
  $currentSourceMatches = (
    $sourceConsistent -and
    $git.Gate -eq 'PASS' -and
    $git.Head -eq $sources[0]
  )
  $allAlarmTimesMatch = (
    $normal.AlarmExpectedTimeMatch -eq 'PASS' -and
    $reboot.AlarmExpectedTimeMatch -eq 'PASS' -and
    $install.AlarmExpectedTimeMatch -eq 'PASS'
  )
  $installEligible = (
    $install.Verdict -eq 'PASS' -and $install.InstallBroadcastVerified
  ) -or (
    $install.Verdict -eq 'INCONCLUSIVE' -and
    $install.InstallBroadcastUnverified
  )
  $eligible = (
    $sourceConsistent -and
    $currentSourceMatches -and
    $allAlarmTimesMatch -and
    $normal.Verdict -eq 'PASS' -and
    $reboot.Verdict -eq 'PASS' -and
    $installEligible
  )
  $recommendation = if ($eligible) {
    'ELIGIBLE_FOR_CLOSE_REVIEW'
  }
  else {
    'KEEP_OPEN'
  }

  Json (
    [ordered]@{
      Recommendation = $recommendation
      SourceConsistency = $sourceConsistent
      CurrentSourceMatches = $currentSourceMatches
      AllAlarmExpectedTimesMatch = $allAlarmTimesMatch
      CurrentGit = $git
      Normal = $normal
      Reboot = $reboot
      Install = $install
      GeneratedAt = Get-Date -Format o
    }
  ) (Join-Path $CaseDirectory 'issue60-summary.json')

  @(
    '## Issue #60 Android Emulator validation result',
    '',
    '| Case | Todo | Expected | Arrival | Alarm time | Verdict |',
    '|---|---|---|---|---|---|',
    "| Normal | ``$($normal.TodoTitle)`` | ``$($normal.ExpectedTime)`` | ``$($normal.ActualArrivalTime)`` | ``$($normal.AlarmExpectedTimeMatch)`` | **$($normal.Verdict)** |",
    "| Reboot | ``$($reboot.TodoTitle)`` | ``$($reboot.ExpectedTime)`` | ``$($reboot.ActualArrivalTime)`` | ``$($reboot.AlarmExpectedTimeMatch)`` | **$($reboot.Verdict)** |",
    "| install-r | ``$($install.TodoTitle)`` | ``$($install.ExpectedTime)`` | ``$($install.ActualArrivalTime)`` | ``$($install.AlarmExpectedTimeMatch)`` | **$($install.Verdict)** |",
    '',
    '### Confirmed facts',
    "- Normal: $($normal.Reason)",
    "- Reboot: $($reboot.Reason)",
    "- install-r: $($install.Reason)",
    "- Source SHA consistent: $sourceConsistent",
    "- Current origin/master matches: $currentSourceMatches",
    "- All expected Alarm times match: $allAlarmTimesMatch",
    '',
    '### Unconfirmed items',
    $(if ($install.Verdict -eq 'INCONCLUSIVE') {
        '- Unique MY_PACKAGE_REPLACED reception evidence.'
      }
      else {
        '- None.'
      }),
    '',
    '### Hypotheses',
    '- None.',
    '',
    '### Counterevidence',
    '- Static checks alone were not treated as notification PASS.',
    '',
    '### Close decision',
    "- **$recommendation**"
  ) -join "`n" |
    Out-File `
      (Join-Path $CaseDirectory 'issue60-summary.md') `
      -Encoding utf8
}
