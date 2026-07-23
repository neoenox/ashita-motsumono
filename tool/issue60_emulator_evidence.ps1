[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet(
    'Preflight',
    'PlanCase',
    'BeginCase',
    'Wait',
    'Capture',
    'Install',
    'Reboot',
    'Finalize',
    'Aggregate'
  )]
  [string]$Action,

  [Parameter(Mandatory)]
  [ValidatePattern('^[A-Za-z0-9_-]+$')]
  [string]$CaseName,

  [ValidateSet('setup', 'normal', 'reboot', 'install-r')]
  [string]$CaseType = 'setup',

  [ValidatePattern('^[\x20-\x7E]*$')]
  [string]$TodoTitle = '',

  [string]$ExpectedTime = '',
  [string]$ActualArrivalTime = '',
  [string]$Verdict = '',
  [string]$Notes = '',
  [string]$Serial = 'emulator-5554',
  [string]$PackageName = 'com.ashita_motsumono',
  [string]$ApkPath = '',
  [string]$OutputRoot = (
    Join-Path (
      [Environment]::GetFolderPath('MyDocuments')
    ) 'ashita-release-evidence'
  ),
  [int]$BootTimeoutSeconds = 300,
  [int]$FailureWaitMinutes = 20,
  [int]$PollSeconds = 15,
  [switch]$RequireInstalledApp,
  [switch]$ExpandNotificationShade,
  [switch]$ResetLogcatBeforeMutation,
  [switch]$InstallBroadcastVerified,
  [switch]$InstallBroadcastUnverified,
  [switch]$ManualScreenshotVerified,
  [string]$NormalCaseName = '',
  [string]$RebootCaseName = '',
  [string]$InstallCaseName = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$global:Issue60Serial = $Serial

if ($Serial -ne 'emulator-5554') {
  throw 'serial must be emulator-5554'
}
if ($PackageName -ne 'com.ashita_motsumono') {
  throw 'package must be com.ashita_motsumono'
}
if ($FailureWaitMinutes -lt 15) {
  throw 'FailureWaitMinutes must be at least 15'
}
if ($PollSeconds -lt 5 -or $PollSeconds -gt 60) {
  throw 'PollSeconds must be 5..60'
}
if ($InstallBroadcastVerified -and $InstallBroadcastUnverified) {
  throw 'broadcast cannot be both verified and unverified'
}

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory 'issue60_portable_paths.ps1')
$RepoRoot = Resolve-Issue60RepositoryRoot `
  -ScriptDirectory $ScriptDirectory

$script:Issue60AdbExecutable = $null
if ($Action -ne 'Aggregate') {
  $global:Issue60AdbExecutable = Resolve-Issue60AdbExecutable
  function global:adb {
    & (Resolve-Issue60AdbExecutable) @args
  }
}

$CaseDirectory = Join-Path $OutputRoot $CaseName
New-Item -ItemType Directory -Force $CaseDirectory | Out-Null

. (Join-Path $ScriptDirectory 'issue60_emulator_evidence_core.ps1')
. (Join-Path $ScriptDirectory 'issue60_emulator_evidence_cases.ps1')

switch ($Action) {
  'Preflight' {
    $p = PreflightState -RequireApp:$RequireInstalledApp
    Json $p (Join-Path $CaseDirectory 'preflight-result.json')
    if ($p.State -eq 'device') {
      $d = Snapshot 'preflight'
      Json $p (Join-Path $d 'preflight-result.json')
    }
    Write-Host $p.Result
  }

  'PlanCase' {
    if (
      $CaseType -eq 'setup' -or
      -not $TodoTitle -or
      -not $ExpectedTime
    ) {
      throw 'case type, title and expected time required'
    }
    $expected = ParseTime $ExpectedTime 'ExpectedTime'
    if ($expected -le [DateTimeOffset]::Now.AddMinutes(4)) {
      throw 'expected time too soon'
    }
    $p = RequirePreflight -RequireApp
    $preSave = Snapshot 'pre-save'
    Json (
      [ordered]@{
        CaseName = $CaseName
        CaseType = $CaseType
        TodoTitle = $TodoTitle
        ExpectedTime = $expected.ToString('o')
        SourceSha = $p.Git.Head
        OriginMaster = $p.Git.OriginMaster
        PlannedAtHost = Get-Date -Format o
        PlannedAtDevice = DeviceTime
        PreSave = $preSave
      }
    ) (PlanPath)
    Write-Host 'PLAN_READY'
  }

  'BeginCase' {
    $plan = AssertPlan
    $expected = ParseTime ([string]$plan.ExpectedTime) 'plan.ExpectedTime'
    if ($expected -le [DateTimeOffset]::Now.AddMinutes(2)) {
      throw 'expected time too soon'
    }
    $p = RequirePreflight -RequireApp
    if ([string]$plan.SourceSha -ne [string]$p.Git.Head) {
      throw 'plan Source SHA differs from current HEAD'
    }
    $baseline = Snapshot 'baseline'
    $registrationPath = Join-Path $CaseDirectory 'alarm-registration.json'
    $registration = AlarmRegistration `
      ([string]$plan.PreSave) `
      $baseline `
      $registrationPath
    $countIncreased = (
      [int]$registration.AfterRelevantLineCount -gt
      [int]$registration.BeforeRelevantLineCount
    )
    $registration |
      Add-Member `
        -NotePropertyName RelevantLineCountIncreased `
        -NotePropertyValue ([bool]$countIncreased) `
        -Force
    if (-not $countIncreased) {
      $registration.Result = 'INCONCLUSIVE'
    }
    Json $registration $registrationPath
    Json (
      [ordered]@{
        CaseName = $CaseName
        CaseType = $CaseType
        TodoTitle = $TodoTitle
        ExpectedTime = $expected.ToString('o')
        SourceSha = $p.Git.Head
        OriginMaster = $p.Git.OriginMaster
        StartedAtHost = Get-Date -Format o
        StartedAtDevice = DeviceTime
        PreSave = [string]$plan.PreSave
        Baseline = $baseline
        AlarmRegistration = $registration
        ProhibitedOperationsUsed = $false
      }
    ) (MetadataPath)
    Write-Host $registration.Result
  }

  'Wait' {
    WaitCase
  }

  'Capture' {
    AssertCase | Out-Null
    RequirePreflight -RequireApp | Out-Null
    Snapshot 'capture' -Shade:$ExpandNotificationShade | Out-Null
  }

  'Install' {
    if (-not $ApkPath) {
      throw 'ApkPath required'
    }
    if ($CaseType -eq 'install-r') {
      AssertCase | Out-Null
      RequirePreflight -RequireApp | Out-Null
    }
    else {
      RequirePreflight | Out-Null
    }
    $resolvedApk = Resolve-Issue60RepositoryPath `
      -Path $ApkPath `
      -RepositoryRoot $RepoRoot
    $apk = (Resolve-Path $resolvedApk).Path
    $before = Snapshot 'before-install'
    $old = LastUpdate
    $hash = (
      Get-FileHash $apk -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($ResetLogcatBeforeMutation) {
      Adb `
        @('logcat', '-c') `
        (Join-Path $before 'logcat-clear.txt') |
        Out-Null
    }
    $d = Join-Path $CaseDirectory "$(Stamp)-install"
    New-Item -ItemType Directory -Force $d | Out-Null
    $x = Adb `
      @('install', '-r', $apk) `
      (Join-Path $d 'adb-install-r.txt')
    Start-Sleep 3
    $after = Snapshot 'after-install'
    $new = LastUpdate
    $ok = (
      $x.ExitCode -eq 0 -and
      (($x.Output -join "`n") -match '(?m)^Success$')
    )
    Json (
      [ordered]@{
        Result = if ($ok) { 'PASS' } else { 'FAIL' }
        ApkSha256 = $hash
        BeforeLastUpdate = $old
        AfterLastUpdate = $new
        LastUpdateTimeChanged = [bool](
          $old -and
          $new -and
          $old -ne $new
        )
        InstallCompletedAt = Get-Date -Format o
        Before = $before
        After = $after
        AppOpenedByScript = $false
      }
    ) (Join-Path $CaseDirectory 'install-result.json')
    if (-not $ok) {
      throw 'install failed'
    }
  }

  'Reboot' {
    if ($CaseType -ne 'reboot') {
      throw 'CaseType reboot required'
    }
    AssertCase | Out-Null
    RequirePreflight -RequireApp | Out-Null
    $before = Snapshot 'before-reboot'
    $old = AdbText @(
      'shell',
      'cat',
      '/proc/sys/kernel/random/boot_id'
    )
    if ($ResetLogcatBeforeMutation) {
      Adb `
        @('logcat', '-c') `
        (Join-Path $before 'logcat-clear.txt') |
        Out-Null
    }
    $requested = Get-Date -Format o
    Adb `
      @('reboot') `
      (Join-Path $CaseDirectory 'adb-reboot.txt') |
      Out-Null
    Adb `
      @('wait-for-device') `
      (Join-Path $CaseDirectory 'adb-wait.txt') |
      Out-Null
    $limit = (Get-Date).AddSeconds($BootTimeoutSeconds)
    do {
      Start-Sleep 2
      $boot = AdbText @(
        'shell',
        'getprop',
        'sys.boot_completed'
      )
    } while (
      $boot -ne '1' -and
      (Get-Date) -lt $limit
    )
    if ($boot -ne '1') {
      Json (
        [ordered]@{
          Result = 'BLOCKED'
          Reason = 'boot timeout'
        }
      ) (Join-Path $CaseDirectory 'reboot-result.json')
      throw 'boot timeout'
    }
    $new = AdbText @(
      'shell',
      'cat',
      '/proc/sys/kernel/random/boot_id'
    )
    $changed = (
      $old -and
      $new -and
      $old -ne $new
    )
    $after = Snapshot 'after-reboot'
    Json (
      [ordered]@{
        Result = if ($changed) { 'PASS' } else { 'BLOCKED' }
        RequestedAt = $requested
        CompletedAt = Get-Date -Format o
        BeforeBootId = $old
        AfterBootId = $new
        BootIdChanged = [bool]$changed
        Before = $before
        After = $after
        AppOpenedByScript = $false
      }
    ) (Join-Path $CaseDirectory 'reboot-result.json')
    if (-not $changed) {
      throw 'boot id unchanged'
    }
  }

  'Finalize' {
    FinalizeCase
  }

  'Aggregate' {
    Aggregate
  }
}
