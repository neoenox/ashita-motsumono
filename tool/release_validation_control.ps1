[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet(
    'ArchiveSession',
    'Doctor',
    'BuildInstall',
    'StartSession',
    'PlanCase',
    'BeginCase',
    'MutateCase',
    'WaitCase',
    'FinalizeCase',
    'Aggregate',
    'WriteTemplates',
    'Evaluate',
    'Status'
  )]
  [string]$Action,

  [ValidateSet('normal', 'reboot', 'install-r')]
  [string]$CaseType = 'normal',

  [ValidateSet('PASS', 'FAIL', 'BLOCKED', 'INCONCLUSIVE')]
  [string]$Verdict = '',

  [string]$ExpectedTime = '',
  [int]$LeadMinutes = 0,
  [string]$Notes = '',
  [string]$Serial = 'emulator-5554',
  [string]$PackageName = 'com.ashita_motsumono',
  [string]$EvidenceRoot = (
    Join-Path (
      [Environment]::GetFolderPath('MyDocuments')
    ) 'ashita-release-evidence'
  ),
  [string]$ApkPath = '.\build\app\outputs\flutter-apk\app-debug.apk',
  [int]$AlarmToleranceMinutes = 5,
  [switch]$ManualScreenshotVerified,
  [switch]$InstallBroadcastVerified,
  [switch]$InstallBroadcastUnverified,
  [switch]$ForceArchiveActive,
  [switch]$ReportOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Serial -ne 'emulator-5554') {
  throw 'serial must be emulator-5554'
}
if ($PackageName -ne 'com.ashita_motsumono') {
  throw 'package must be com.ashita_motsumono'
}
if ($AlarmToleranceMinutes -lt 1 -or $AlarmToleranceMinutes -gt 30) {
  throw 'AlarmToleranceMinutes must be 1..30'
}
if ($InstallBroadcastVerified -and $InstallBroadcastUnverified) {
  throw 'broadcast cannot be both verified and unverified'
}

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDirectory = Split-Path -Parent $ScriptPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptDirectory '..')).Path
$Backend = Join-Path $ScriptDirectory 'release_validation_session.ps1'
$AlarmParser = Join-Path $ScriptDirectory 'issue60_alarm_time_evidence.ps1'
$StatePath = Join-Path $EvidenceRoot 'release-validation-state.json'
$SessionPath = Join-Path $EvidenceRoot 'release-session.json'
$StatusPath = Join-Path $EvidenceRoot 'release-validation-status.json'
$ReadinessPath = Join-Path $EvidenceRoot 'release-readiness.json'

function New-Utf8NoBomEncoding {
  [Text.UTF8Encoding]::new($false, $true)
}

function Get-FullPath {
  param([Parameter(Mandatory)][string]$Path)
  if ([IO.Path]::IsPathRooted($Path)) {
    return [IO.Path]::GetFullPath($Path)
  }
  [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Write-JsonFile {
  param(
    [Parameter(Mandatory)]$Value,
    [Parameter(Mandatory)][string]$Path
  )
  $fullPath = Get-FullPath $Path
  $directory = [IO.Path]::GetDirectoryName($fullPath)
  if ($directory) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
  }
  $json = ($Value | ConvertTo-Json -Depth 20) +
    [Environment]::NewLine
  [IO.File]::WriteAllText(
    $fullPath,
    $json,
    (New-Utf8NoBomEncoding)
  )
}

function Read-JsonFile {
  param([Parameter(Mandatory)][string]$Path)
  $fullPath = Get-FullPath $Path
  if (-not (Test-Path $fullPath)) {
    throw "missing file: $fullPath"
  }
  [IO.File]::ReadAllText(
    $fullPath,
    (New-Utf8NoBomEncoding)
  ) | ConvertFrom-Json
}

function Read-OptionalJson {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path $Path)) {
    return $null
  }
  try {
    Read-JsonFile $Path
  }
  catch {
    [pscustomobject][ordered]@{
      readError = $_.Exception.Message
      path = (Get-FullPath $Path)
    }
  }
}

function Get-OptionalProperty {
  param(
    $Object,
    [Parameter(Mandatory)][string]$Name,
    $Default = $null
  )
  if ($null -eq $Object) {
    return $Default
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($property) {
    return $property.Value
  }
  $Default
}

function Get-GitValue {
  param([Parameter(Mandatory)][string[]]$Arguments)
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    return ''
  }
  Push-Location $RepoRoot
  try {
    $value = & git @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
      return ''
    }
    ($value | Out-String).Trim()
  }
  finally {
    Pop-Location
  }
}

function Get-GitGate {
  $head = Get-GitValue @('rev-parse', 'HEAD')
  $originMaster = Get-GitValue @('rev-parse', 'origin/master')
  $tracked = Get-GitValue @(
    'status',
    '--porcelain',
    '--untracked-files=no'
  )
  $gate = if (-not $head -or -not $originMaster) {
    'UNKNOWN'
  }
  elseif ($head -ne $originMaster) {
    'HEAD_MISMATCH'
  }
  elseif ($tracked) {
    'TRACKED_CHANGES'
  }
  else {
    'PASS'
  }
  [pscustomobject][ordered]@{
    gate = $gate
    head = $head
    originMaster = $originMaster
    trackedClean = (-not $tracked)
    trackedStatus = $tracked
  }
}

function Get-BackendArguments {
  $arguments = [System.Collections.Generic.List[string]]::new()
  $arguments.Add('-Action')
  $arguments.Add($Action)
  $arguments.Add('-CaseType')
  $arguments.Add($CaseType)
  $arguments.Add('-Serial')
  $arguments.Add($Serial)
  $arguments.Add('-PackageName')
  $arguments.Add($PackageName)
  $arguments.Add('-EvidenceRoot')
  $arguments.Add($EvidenceRoot)
  $arguments.Add('-ApkPath')
  $arguments.Add($ApkPath)
  if ($Verdict) {
    $arguments.Add('-Verdict')
    $arguments.Add($Verdict)
  }
  if ($ExpectedTime) {
    $arguments.Add('-ExpectedTime')
    $arguments.Add($ExpectedTime)
  }
  if ($LeadMinutes -gt 0) {
    $arguments.Add('-LeadMinutes')
    $arguments.Add([string]$LeadMinutes)
  }
  if ($Notes) {
    $arguments.Add('-Notes')
    $arguments.Add($Notes)
  }
  if ($ManualScreenshotVerified) {
    $arguments.Add('-ManualScreenshotVerified')
  }
  if ($InstallBroadcastVerified) {
    $arguments.Add('-InstallBroadcastVerified')
  }
  if ($InstallBroadcastUnverified) {
    $arguments.Add('-InstallBroadcastUnverified')
  }
  if ($ReportOnly) {
    $arguments.Add('-ReportOnly')
  }
  @($arguments)
}

function Invoke-Backend {
  if (-not (Test-Path $Backend)) {
    throw "missing backend: $Backend"
  }
  $arguments = Get-BackendArguments
  & $Backend @arguments
}

function Get-State {
  if (-not (Test-Path $StatePath)) {
    return [pscustomobject][ordered]@{
      sessionStarted = $false
      sourceSha = ''
      cases = [pscustomobject][ordered]@{
        normal = $null
        reboot = $null
        'install-r' = $null
      }
    }
  }
  Read-JsonFile $StatePath
}

function Get-CaseFromState {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][string]$Type
  )
  $casesProperty = $State.PSObject.Properties['cases']
  if (-not $casesProperty -or -not $casesProperty.Value) {
    return $null
  }
  $property = $casesProperty.Value.PSObject.Properties[$Type]
  if (-not $property) {
    return $null
  }
  $property.Value
}

function Get-CaseDirectory {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][string]$Type
  )
  $case = Get-CaseFromState $State $Type
  if (-not $case) {
    throw "case is not planned: $Type"
  }
  $caseName = [string](Get-OptionalProperty $case 'caseName' '')
  if (-not $caseName) {
    throw "caseName missing for $Type"
  }
  Join-Path $EvidenceRoot $caseName
}

function Enhance-AlarmTimingEvidence {
  $state = Get-State
  $case = Get-CaseFromState $state $CaseType
  if (-not $case) {
    throw "case is not planned: $CaseType"
  }
  $caseDirectory = Get-CaseDirectory $state $CaseType
  $registrationPath = Join-Path $caseDirectory 'alarm-registration.json'
  $registration = Read-JsonFile $registrationPath
  $beforeSnapshot = [string](
    Get-OptionalProperty $registration 'BeforeSnapshot' ''
  )
  $afterSnapshot = [string](
    Get-OptionalProperty $registration 'AfterSnapshot' ''
  )
  if (-not $beforeSnapshot -or -not $afterSnapshot) {
    throw 'alarm registration snapshots are missing'
  }
  $beforeAlarm = Join-Path $beforeSnapshot 'alarm.txt'
  $afterAlarm = Join-Path $afterSnapshot 'alarm.txt'
  $expected = [string](Get-OptionalProperty $case 'expectedTime' '')
  if (-not $expected) {
    throw 'case expectedTime is missing'
  }
  $timingPath = Join-Path $caseDirectory 'alarm-time-evidence.json'
  $timing = & $AlarmParser `
    -BeforeAlarmPath $beforeAlarm `
    -AfterAlarmPath $afterAlarm `
    -ExpectedTime $expected `
    -Destination $timingPath `
    -PackageName $PackageName `
    -ToleranceMinutes $AlarmToleranceMinutes

  $registration |
    Add-Member `
      -NotePropertyName ExpectedTimeMatch `
      -NotePropertyValue ([string]$timing.result) `
      -Force
  $registration |
    Add-Member `
      -NotePropertyName ExpectedTimeToleranceMinutes `
      -NotePropertyValue $AlarmToleranceMinutes `
      -Force
  $registration |
    Add-Member `
      -NotePropertyName AlarmTimeEvidence `
      -NotePropertyValue $timingPath `
      -Force
  $registration |
    Add-Member `
      -NotePropertyName AddedTimeCandidates `
      -NotePropertyValue @($timing.addedCandidates) `
      -Force
  $registration |
    Add-Member `
      -NotePropertyName MatchingTimeCandidates `
      -NotePropertyValue @($timing.matchingCandidates) `
      -Force

  $registrationDetected = (
    [int](Get-OptionalProperty $registration 'AddedLineCount' 0) -gt 0 -and
    [bool](Get-OptionalProperty $registration 'RelevantLineCountIncreased' $false)
  )
  if (-not $registrationDetected -or $timing.result -ne 'PASS') {
    $registration.Result = 'INCONCLUSIVE'
  }
  else {
    $registration.Result = 'PASS'
  }
  Write-JsonFile $registration $registrationPath

  $metadataPath = Join-Path $caseDirectory 'case-metadata.json'
  if (Test-Path $metadataPath) {
    $metadata = Read-JsonFile $metadataPath
    $metadata |
      Add-Member `
        -NotePropertyName AlarmRegistration `
        -NotePropertyValue $registration `
        -Force
    Write-JsonFile $metadata $metadataPath
  }
  $registration
}

function Assert-AlarmTimingGate {
  $state = Get-State
  $caseDirectory = Get-CaseDirectory $state $CaseType
  $registrationPath = Join-Path $caseDirectory 'alarm-registration.json'
  $registration = Read-JsonFile $registrationPath
  $timeMatch = [string](
    Get-OptionalProperty $registration 'ExpectedTimeMatch' ''
  )
  if ($registration.Result -ne 'PASS' -or $timeMatch -ne 'PASS') {
    throw (
      'alarm registration or expected-time evidence is not PASS; ' +
      'finalize as INCONCLUSIVE instead of waiting or approving'
    )
  }
  $registration
}

function Archive-Session {
  $root = Get-FullPath $EvidenceRoot
  if (-not (Test-Path $root)) {
    return [pscustomobject][ordered]@{
      result = 'NO_EVIDENCE'
      source = $root
      destination = ''
      forced = $ForceArchiveActive.IsPresent
    }
  }
  $items = @(
    Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue
  )
  if ($items.Count -eq 0) {
    return [pscustomobject][ordered]@{
      result = 'NO_EVIDENCE'
      source = $root
      destination = ''
      forced = $ForceArchiveActive.IsPresent
    }
  }

  $session = Read-OptionalJson $SessionPath
  $state = Read-OptionalJson $StatePath
  $summaryPath = Join-Path (
    Join-Path $root 'ISSUE60_SUMMARY'
  ) 'issue60-summary.json'
  $active = (
    $null -ne $session -and
    -not (Test-Path $summaryPath)
  )
  if ($active -and -not $ForceArchiveActive) {
    throw (
      'active release session cannot be archived without ' +
      '-ForceArchiveActive'
    )
  }

  $parent = [IO.Path]::GetDirectoryName($root)
  $leaf = [IO.Path]::GetFileName($root.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  ))
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $destination = Join-Path $parent "$leaf-archive-$stamp"
  $suffix = 1
  while (Test-Path $destination) {
    $destination = Join-Path $parent "$leaf-archive-$stamp-$suffix"
    $suffix++
  }

  $sourceSha = [string](Get-OptionalProperty $session 'sourceSha' '')
  Move-Item -LiteralPath $root -Destination $destination
  New-Item -ItemType Directory -Force $root | Out-Null
  $manifest = [pscustomobject][ordered]@{
    result = 'ARCHIVED'
    source = $root
    destination = $destination
    archivedAt = Get-Date -Format o
    sourceSha = $sourceSha
    sessionWasActive = [bool]$active
    forced = $ForceArchiveActive.IsPresent
    previousState = $state
  }
  Write-JsonFile $manifest (Join-Path $destination 'archive-manifest.json')
  Write-JsonFile $manifest (Join-Path $root 'archive-last-result.json')
  $manifest
}

function Get-CaseDiagnostic {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][string]$Type
  )
  $case = Get-CaseFromState $State $Type
  if (-not $case) {
    return [pscustomobject][ordered]@{
      caseType = $Type
      planned = $false
      status = 'NOT_STARTED'
      verdict = ''
      caseName = ''
      alarmRegistration = $null
      wait = $null
      result = $null
      evidenceFiles = @()
    }
  }
  $caseName = [string](Get-OptionalProperty $case 'caseName' '')
  $directory = Join-Path $EvidenceRoot $caseName
  $registrationPath = Join-Path $directory 'alarm-registration.json'
  $timingPath = Join-Path $directory 'alarm-time-evidence.json'
  $waitPath = Join-Path $directory 'wait-result.json'
  $resultPath = Join-Path $directory 'case-result.json'
  $registration = Read-OptionalJson $registrationPath
  $timing = Read-OptionalJson $timingPath
  $wait = Read-OptionalJson $waitPath
  $result = Read-OptionalJson $resultPath
  [pscustomobject][ordered]@{
    caseType = $Type
    planned = $true
    status = [string](Get-OptionalProperty $case 'status' 'UNKNOWN')
    verdict = [string](Get-OptionalProperty $case 'verdict' '')
    caseName = $caseName
    todoTitle = [string](Get-OptionalProperty $case 'todoTitle' '')
    expectedTime = [string](Get-OptionalProperty $case 'expectedTime' '')
    alarmRegistration = $registration
    alarmExpectedTimeMatch = [string](
      Get-OptionalProperty $registration 'ExpectedTimeMatch' ''
    )
    alarmTiming = $timing
    wait = $wait
    result = $result
    evidenceFiles = @(
      $registrationPath,
      $timingPath,
      $waitPath,
      $resultPath
    ) | Where-Object { Test-Path $_ }
  }
}

function Get-NextStep {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)]$Normal,
    [Parameter(Mandatory)]$Reboot,
    [Parameter(Mandatory)]$InstallCase,
    [bool]$DoctorPassed,
    [bool]$ApkInstalled
  )
  $base = '.\tool\release_validation_control.ps1'
  if (-not $DoctorPassed) {
    return [pscustomobject]@{
      action = 'Doctor'
      command = "$base -Action Doctor -EvidenceRoot `"$EvidenceRoot`""
      manual = ''
    }
  }
  if (-not $ApkInstalled) {
    return [pscustomobject]@{
      action = 'BuildInstall'
      command = "$base -Action BuildInstall -EvidenceRoot `"$EvidenceRoot`""
      manual = ''
    }
  }
  if (-not [bool](Get-OptionalProperty $State 'sessionStarted' $false)) {
    return [pscustomobject]@{
      action = 'StartSession'
      command = "$base -Action StartSession -EvidenceRoot `"$EvidenceRoot`""
      manual = 'Open the app once, grant notification permission, return Home.'
    }
  }
  foreach ($item in @(
      [pscustomobject]@{ type = 'normal'; value = $Normal },
      [pscustomobject]@{ type = 'reboot'; value = $Reboot },
      [pscustomobject]@{ type = 'install-r'; value = $InstallCase }
    )) {
    $type = $item.type
    $case = $item.value
    if (-not $case.planned) {
      return [pscustomobject]@{
        action = 'PlanCase'
        command = "$base -Action PlanCase -CaseType $type -EvidenceRoot `"$EvidenceRoot`""
        manual = ''
      }
    }
    if ($case.status -eq 'PLANNED') {
      return [pscustomobject]@{
        action = 'BeginCase'
        command = "$base -Action BeginCase -CaseType $type -EvidenceRoot `"$EvidenceRoot`""
        manual = "Create Todo $($case.todoTitle), save, go Home, and do not reopen the app."
      }
    }
    if ($case.status -eq 'BEGUN') {
      if ($case.alarmExpectedTimeMatch -ne 'PASS') {
        return [pscustomobject]@{
          action = 'FinalizeCase'
          command = "$base -Action FinalizeCase -CaseType $type -Verdict INCONCLUSIVE -Notes `"Alarm registration or expected-time evidence incomplete`" -EvidenceRoot `"$EvidenceRoot`""
          manual = 'Do not wait. Review alarm-registration.json and alarm-time-evidence.json.'
        }
      }
      if ($type -eq 'normal') {
        return [pscustomobject]@{
          action = 'WaitCase'
          command = "$base -Action WaitCase -CaseType normal -EvidenceRoot `"$EvidenceRoot`""
          manual = 'Keep the app closed.'
        }
      }
      return [pscustomobject]@{
        action = 'MutateCase'
        command = "$base -Action MutateCase -CaseType $type -EvidenceRoot `"$EvidenceRoot`""
        manual = 'Keep the app closed.'
      }
    }
    if ($case.status -eq 'MUTATED') {
      return [pscustomobject]@{
        action = 'WaitCase'
        command = "$base -Action WaitCase -CaseType $type -EvidenceRoot `"$EvidenceRoot`""
        manual = 'Keep the app closed.'
      }
    }
    if ($case.status -eq 'WAITED') {
      return [pscustomobject]@{
        action = 'FinalizeCase'
        command = "$base -Action FinalizeCase -CaseType $type -Verdict `<VERDICT`> -Notes `"Evidence reviewed`" -EvidenceRoot `"$EvidenceRoot`""
        manual = 'Review the screenshot, notification dump, wait result, and causality before selecting a verdict.'
      }
    }
    if ($case.verdict -ne 'PASS' -and $type -ne 'install-r') {
      return [pscustomobject]@{
        action = 'PlanCase'
        command = "$base -Action PlanCase -CaseType $type -EvidenceRoot `"$EvidenceRoot`""
        manual = 'Use a new future Todo; do not reuse the previous title.'
      }
    }
  }
  [pscustomobject]@{
    action = 'Aggregate'
    command = "$base -Action Aggregate -EvidenceRoot `"$EvidenceRoot`""
    manual = 'Confirm all three finalized cases use the same Source SHA.'
  }
}

function Show-Status {
  New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null
  $state = Get-State
  $git = Get-GitGate
  $doctor = Read-OptionalJson (
    Join-Path $EvidenceRoot 'release-validation-doctor.json'
  )
  $install = Read-OptionalJson (
    Join-Path (Join-Path $EvidenceRoot 'SETUP_INSTALL') 'install-result.json'
  )
  $appPreflight = Read-OptionalJson (
    Join-Path (Join-Path $EvidenceRoot 'SETUP_APP') 'preflight-result.json'
  )
  $session = Read-OptionalJson $SessionPath
  $readiness = Read-OptionalJson $ReadinessPath
  $normal = Get-CaseDiagnostic $state 'normal'
  $reboot = Get-CaseDiagnostic $state 'reboot'
  $installCase = Get-CaseDiagnostic $state 'install-r'
  $doctorPassed = (
    [string](Get-OptionalProperty $doctor 'result' '') -eq 'PASS'
  )
  $apkInstalled = (
    [string](Get-OptionalProperty $install 'Result' '') -eq 'PASS'
  )
  $permission = [string](
    Get-OptionalProperty $appPreflight 'Permission' 'UNKNOWN'
  )
  $next = Get-NextStep `
    -State $state `
    -Normal $normal `
    -Reboot $reboot `
    -InstallCase $installCase `
    -DoctorPassed $doctorPassed `
    -ApkInstalled $apkInstalled
  $status = [pscustomobject][ordered]@{
    generatedAt = Get-Date -Format o
    git = $git
    doctorPassed = $doctorPassed
    apkInstalled = $apkInstalled
    notificationPermission = $permission
    sessionStarted = [bool](
      Get-OptionalProperty $state 'sessionStarted' $false
    )
    sessionSourceSha = [string](
      Get-OptionalProperty $session 'sourceSha' ''
    )
    cases = [pscustomobject][ordered]@{
      normal = $normal
      reboot = $reboot
      'install-r' = $installCase
    }
    readiness = $readiness
    nextAction = $next.action
    nextCommand = $next.command
    manualAction = $next.manual
    evidenceFiles = @(
      $StatePath,
      $SessionPath,
      $ReadinessPath
    ) | Where-Object { Test-Path $_ }
  }
  Write-JsonFile $status $StatusPath
  $status
}

switch ($Action) {
  'ArchiveSession' {
    Archive-Session
  }
  'Status' {
    Show-Status
  }
  'BeginCase' {
    Invoke-Backend | Out-Null
    Enhance-AlarmTimingEvidence
  }
  'WaitCase' {
    Assert-AlarmTimingGate | Out-Null
    Invoke-Backend
  }
  'FinalizeCase' {
    if ($Verdict -eq 'PASS' -or $Verdict -eq 'FAIL') {
      Assert-AlarmTimingGate | Out-Null
    }
    Invoke-Backend
  }
  default {
    Invoke-Backend
  }
}
