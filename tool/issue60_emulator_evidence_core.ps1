function Stamp {
  Get-Date -Format 'yyyyMMdd-HHmmss'
}

function Json($Value, $Path) {
  $fullPath = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  }
  else {
    [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
  }
  $directory = [IO.Path]::GetDirectoryName($fullPath)
  if ($directory) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
  }
  $json = ($Value | ConvertTo-Json -Depth 12) +
    [Environment]::NewLine
  [IO.File]::WriteAllText(
    $fullPath,
    $json,
    [Text.UTF8Encoding]::new($false, $true)
  )
}

function Adb([string[]]$AdbArguments, [string]$Out, [switch]$AllowFailure) {
  @(
    "command=adb -s $global:Issue60Serial $($AdbArguments -join ' ')",
    "host_time=$(Get-Date -Format o)"
  ) | Out-File $Out -Encoding utf8
  $text = & (Resolve-Issue60AdbExecutable) -s $global:Issue60Serial @AdbArguments 2>&1
  $code = $LASTEXITCODE
  $text | Out-File $Out -Append -Encoding utf8
  "exit_code=$code" | Out-File $Out -Append -Encoding utf8
  if ($code -ne 0 -and -not $AllowFailure) {
    throw "adb failed: $($AdbArguments -join ' ')"
  }
  [pscustomobject]@{ Output = @($text); ExitCode = $code }
}

function AdbText([string[]]$AdbArguments) {
  $x = & (Resolve-Issue60AdbExecutable) -s $global:Issue60Serial @AdbArguments 2>$null
  if ($LASTEXITCODE -ne 0) {
    return ''
  }
  ($x | Out-String).Trim()
}

function ParseTime([string]$Value, [string]$Name) {
  $v = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse(
      $Value,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind,
      [ref]$v
    )) {
    throw "$Name must be ISO 8601"
  }
  $v
}

function DeviceTime {
  $x = AdbText @('shell', 'date', '+%Y-%m-%dT%H:%M:%S%z')
  if ($x -match '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})([+-]\d{2})(\d{2})$') {
    return "$($Matches[1])$($Matches[2]):$($Matches[3])"
  }
  $x
}

function Permission {
  $p = AdbText @('shell', 'dumpsys', 'package', $PackageName)
  $o = AdbText @(
    'shell',
    'cmd',
    'appops',
    'get',
    $PackageName,
    'POST_NOTIFICATION'
  )
  if (
    $p -match 'POST_NOTIFICATIONS:\s+granted=false' -or
    $o -match '(?im)POST_NOTIFICATION:\s*(deny|ignore|errored)'
  ) {
    return 'DENIED'
  }
  if (
    $p -match 'POST_NOTIFICATIONS:\s+granted=true' -and
    $o -notmatch '(?im)POST_NOTIFICATION:\s*(deny|ignore|errored)'
  ) {
    return 'GRANTED'
  }
  'UNKNOWN'
}

function GitState {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    return [pscustomobject]@{
      Gate = 'UNKNOWN'
      Head = ''
      OriginMaster = ''
      Clean = $false
    }
  }
  $h = (& git rev-parse HEAD 2>$null | Out-String).Trim()
  $o = (& git rev-parse origin/master 2>$null | Out-String).Trim()
  $s = (
    & git status --porcelain --untracked-files=no 2>$null |
      Out-String
  ).Trim()
  $g = if (-not $h -or -not $o) {
    'UNKNOWN'
  }
  elseif ($h -ne $o) {
    'HEAD_MISMATCH'
  }
  elseif ($s) {
    'TRACKED_CHANGES'
  }
  else {
    'PASS'
  }
  [pscustomobject]@{
    Gate = $g
    Head = $h
    OriginMaster = $o
    Clean = (-not $s)
    TrackedStatus = $s
  }
}

function Foreground {
  $a = AdbText @('shell', 'dumpsys', 'activity', 'activities')
  $l = @(
    $a -split "`r?`n" |
      Where-Object {
        $_ -match 'mResumedActivity|topResumedActivity'
      }
  ) -join "`n"
  [pscustomobject]@{
    IsApp = ($l -match [regex]::Escape($PackageName))
    Evidence = $l
  }
}

function LastUpdate {
  $p = AdbText @('shell', 'dumpsys', 'package', $PackageName)
  $m = [regex]::Match($p, '(?m)^\s*lastUpdateTime=(.+)$')
  if ($m.Success) {
    $m.Groups[1].Value.Trim()
  }
  else {
    ''
  }
}

function PreflightState([switch]$RequireApp) {
  $state = AdbText @('get-state')
  $boot = AdbText @('shell', 'getprop', 'sys.boot_completed')
  $qemu = AdbText @('shell', 'getprop', 'ro.kernel.qemu')
  $tz = AdbText @('shell', 'getprop', 'persist.sys.timezone')
  $installed = (
    AdbText @('shell', 'pm', 'path', $PackageName)
  ) -match '^package:'
  $perm = Permission
  $git = GitState
  $ok = (
    $state -eq 'device' -and
    $boot -eq '1' -and
    $qemu -eq '1' -and
    $tz -eq 'Asia/Tokyo' -and
    $git.Gate -eq 'PASS' -and
    (
      (-not $RequireApp) -or
      ($installed -and $perm -eq 'GRANTED')
    )
  )
  [pscustomobject]@{
    Result = if ($ok) { 'PASS' } else { 'BLOCKED' }
    State = $state
    Boot = $boot
    Qemu = $qemu
    Timezone = $tz
    Installed = $installed
    Permission = $perm
    Git = $git
  }
}

function RequirePreflight([switch]$RequireApp) {
  $p = PreflightState -RequireApp:$RequireApp
  if ($p.Result -ne 'PASS') {
    throw "preflight blocked: $($p | ConvertTo-Json -Compress -Depth 5)"
  }
  $p
}

function FilterEvidence(
  $Source,
  $Destination,
  [string[]]$Patterns
) {
  $effectivePatterns = @($Patterns | Where-Object { $_ })
  if ((Test-Path $Source) -and $effectivePatterns.Count -gt 0) {
    Select-String `
      $Source `
      -Pattern $effectivePatterns `
      -SimpleMatch `
      -Context 4, 8 |
      Out-File $Destination -Encoding utf8
  }
}

function RelevantAlarmLines([string]$Path) {
  if (-not (Test-Path $Path)) {
    return @()
  }
  $patterns = @(
    [regex]::Escape($PackageName),
    'ScheduledNotificationReceiver',
    'flutterlocalnotifications'
  )
  @(
    Get-Content $Path |
      ForEach-Object { $_.Trim() } |
      Where-Object {
        $_ -and (
          $_ -match $patterns[0] -or
          $_ -match $patterns[1] -or
          $_ -match $patterns[2]
        )
      }
  )
}

function AlarmRegistration(
  [string]$BeforeDirectory,
  [string]$AfterDirectory,
  [string]$Destination
) {
  $before = @(
    RelevantAlarmLines (Join-Path $BeforeDirectory 'alarm.txt')
  )
  $after = @(
    RelevantAlarmLines (Join-Path $AfterDirectory 'alarm.txt')
  )
  $beforeCounts = @{}
  $afterCounts = @{}
  foreach ($line in $before) {
    if (-not $beforeCounts.ContainsKey($line)) {
      $beforeCounts[$line] = 0
    }
    $beforeCounts[$line]++
  }
  foreach ($line in $after) {
    if (-not $afterCounts.ContainsKey($line)) {
      $afterCounts[$line] = 0
    }
    $afterCounts[$line]++
  }
  $added = [System.Collections.Generic.List[string]]::new()
  foreach ($line in $afterCounts.Keys) {
    $beforeCount = if ($beforeCounts.ContainsKey($line)) {
      [int]$beforeCounts[$line]
    }
    else {
      0
    }
    $delta = [int]$afterCounts[$line] - $beforeCount
    for ($index = 0; $index -lt $delta; $index++) {
      $added.Add([string]$line)
    }
  }
  $registered = $added.Count -gt 0
  $expectedEpoch = if ($ExpectedTime) {
    (ParseTime $ExpectedTime 'ExpectedTime').ToUnixTimeMilliseconds()
  }
  $alarmEpochs = @(
    $added |
      ForEach-Object {
        if ($_ -match 'origWhen (?<epoch>\d+)') {
          [long]$Matches.epoch
        }
      }
  )
  $expectedTimeMatch = if (
    $null -ne $expectedEpoch -and
    ($alarmEpochs -contains $expectedEpoch)
  ) {
    'PASS'
  }
  else {
    'INCONCLUSIVE'
  }
  $result = [pscustomobject][ordered]@{
    Result = if ($registered) { 'PASS' } else { 'INCONCLUSIVE' }
    ExpectedTime = $ExpectedTime
    ExpectedTimeMatch = $expectedTimeMatch
    BeforeRelevantLineCount = $before.Count
    AfterRelevantLineCount = $after.Count
    AddedLineCount = $added.Count
    AddedLines = @($added)
    BeforeSnapshot = $BeforeDirectory
    AfterSnapshot = $AfterDirectory
    RecordedAt = Get-Date -Format o
  }
  Json $result $Destination
  $result
}

function Screen($Directory, [switch]$Shade) {
  if ($Shade) {
    Adb `
      @('shell', 'cmd', 'statusbar', 'expand-notifications') `
      (Join-Path $Directory 'expand-shade.txt') `
      -AllowFailure |
      Out-Null
    Start-Sleep 2
  }
  $n = "issue60-$CaseName-$(Stamp)"
  $png = "/sdcard/Download/$n.png"
  $xml = "/sdcard/Download/$n.xml"
  Adb `
    @('shell', 'uiautomator', 'dump', $xml) `
    (Join-Path $Directory 'ui-dump.txt') `
    -AllowFailure |
    Out-Null
  Adb `
    @('pull', $xml, (Join-Path $Directory 'ui.xml')) `
    (Join-Path $Directory 'ui-pull.txt') `
    -AllowFailure |
    Out-Null
  Adb `
    @('shell', 'screencap', '-p', $png) `
    (Join-Path $Directory 'screen-command.txt') `
    -AllowFailure |
    Out-Null
  Adb `
    @('pull', $png, (Join-Path $Directory 'screen.png')) `
    (Join-Path $Directory 'screen-pull.txt') `
    -AllowFailure |
    Out-Null
  Adb `
    @('shell', 'rm', '-f', $xml, $png) `
    (Join-Path $Directory 'remote-cleanup.txt') `
    -AllowFailure |
    Out-Null
  if ($Shade) {
    Adb `
      @('shell', 'cmd', 'statusbar', 'collapse') `
      (Join-Path $Directory 'collapse-shade.txt') `
      -AllowFailure |
      Out-Null
  }
}

function Snapshot([string]$Label, [switch]$Shade) {
  $d = Join-Path $CaseDirectory "$(Stamp)-$Label"
  New-Item -ItemType Directory -Force $d | Out-Null
  Json (
    [ordered]@{
      HostTime = Get-Date -Format o
      Action = $Action
      CaseName = $CaseName
      CaseType = $CaseType
      TodoTitle = $TodoTitle
      ExpectedTime = $ExpectedTime
      Serial = $Serial
      Package = $PackageName
      WorkingDirectory = (Get-Location).Path
      Git = GitState
    }
  ) (Join-Path $d 'host-metadata.json')
  $commands = @{
    'state.txt' = @('get-state')
    'device-time.txt' = @('shell', 'date')
    'device-time-iso.txt' = @(
      'shell',
      'date',
      '+%Y-%m-%dT%H:%M:%S%z'
    )
    'uptime.txt' = @('shell', 'cat', '/proc/uptime')
    'boot-id.txt' = @(
      'shell',
      'cat',
      '/proc/sys/kernel/random/boot_id'
    )
    'boot-completed.txt' = @(
      'shell',
      'getprop',
      'sys.boot_completed'
    )
    'qemu.txt' = @('shell', 'getprop', 'ro.kernel.qemu')
    'android.txt' = @(
      'shell',
      'getprop',
      'ro.build.version.release'
    )
    'api.txt' = @(
      'shell',
      'getprop',
      'ro.build.version.sdk'
    )
    'model.txt' = @(
      'shell',
      'getprop',
      'ro.product.model'
    )
    'avd.txt' = @(
      'shell',
      'getprop',
      'ro.boot.qemu.avd_name'
    )
    'timezone.txt' = @(
      'shell',
      'getprop',
      'persist.sys.timezone'
    )
    'package.txt' = @(
      'shell',
      'dumpsys',
      'package',
      $PackageName
    )
    'appop.txt' = @(
      'shell',
      'cmd',
      'appops',
      'get',
      $PackageName,
      'POST_NOTIFICATION'
    )
    'activities.txt' = @(
      'shell',
      'dumpsys',
      'activity',
      'activities'
    )
    'power.txt' = @('shell', 'dumpsys', 'power')
    'deviceidle.txt' = @('shell', 'dumpsys', 'deviceidle')
    'alarm.txt' = @('shell', 'dumpsys', 'alarm')
    'notification.txt' = @(
      'shell',
      'dumpsys',
      'notification',
      '--noredact'
    )
    'logcat.txt' = @('logcat', '-d', '-v', 'threadtime')
  }
  foreach ($k in $commands.Keys) {
    Adb `
      $commands[$k] `
      (Join-Path $d $k) `
      -AllowFailure |
      Out-Null
  }
  FilterEvidence `
    (Join-Path $d 'alarm.txt') `
    (Join-Path $d 'alarm-filtered.txt') `
    @(
      $PackageName,
      'ScheduledNotification',
      'flutterlocalnotifications'
    )
  FilterEvidence `
    (Join-Path $d 'notification.txt') `
    (Join-Path $d 'notification-filtered.txt') `
    @($PackageName, $TodoTitle)
  FilterEvidence `
    (Join-Path $d 'activities.txt') `
    (Join-Path $d 'foreground-filtered.txt') `
    @(
      'mResumedActivity',
      'topResumedActivity',
      $PackageName
    )
  FilterEvidence `
    (Join-Path $d 'logcat.txt') `
    (Join-Path $d 'logcat-filtered.txt') `
    @(
      $PackageName,
      'MY_PACKAGE_REPLACED',
      'BOOT_COMPLETED',
      'ScheduledNotification',
      'flutterlocalnotifications'
    )
  Screen $d -Shade:$Shade
  $ui = if (Test-Path (Join-Path $d 'ui.xml')) {
    Get-Content -Raw (Join-Path $d 'ui.xml')
  }
  else {
    ''
  }
  $not = Get-Content -Raw (Join-Path $d 'notification.txt')
  $fg = Foreground
  $uiTitle = (
    $TodoTitle -and
    $ui -match [regex]::Escape($TodoTitle)
  )
  $dumpTitle = (
    $TodoTitle -and
    $not -match [regex]::Escape($TodoTitle)
  )
  Json (
    [ordered]@{
      HostTime = Get-Date -Format o
      DeviceTime = DeviceTime
      Permission = Permission
      ShadeRequested = $Shade.IsPresent
      TitleInUi = [bool]$uiTitle
      TitleInDump = [bool]$dumpTitle
      TitleEvidence = [bool]($uiTitle -or $dumpTitle)
      AppForeground = $fg.IsApp
      ForegroundEvidence = $fg.Evidence
      LastUpdateTime = LastUpdate
    }
  ) (Join-Path $d 'snapshot-summary.json')
  Write-Host "evidence: $d"
  $d
}
