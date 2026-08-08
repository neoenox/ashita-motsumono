[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet(
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
  [switch]$ManualScreenshotVerified,
  [switch]$InstallBroadcastVerified,
  [switch]$InstallBroadcastUnverified,
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
if ($InstallBroadcastVerified -and $InstallBroadcastUnverified) {
  throw 'broadcast cannot be both verified and unverified'
}

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDirectory '..')).Path
$Issue60Tool = Join-Path $ScriptDirectory 'issue60_emulator_evidence.ps1'
$Orchestrator = Join-Path $ScriptDirectory 'release_execution_orchestrator.py'
$StatePath = Join-Path $EvidenceRoot 'release-validation-state.json'
$SessionPath = Join-Path $EvidenceRoot 'release-session.json'
$PlayEvidencePath = Join-Path $EvidenceRoot 'play-console-evidence.json'
$ManifestPath = Join-Path $EvidenceRoot 'release-manifest.json'
$InternalEvidencePath = Join-Path $EvidenceRoot 'internal-test-evidence.json'
$ReadinessJsonPath = Join-Path $EvidenceRoot 'release-readiness.json'
$ReadinessMarkdownPath = Join-Path $EvidenceRoot 'release-readiness.md'

New-Item -ItemType Directory -Force $EvidenceRoot | Out-Null

function Get-FullPath {
  param([Parameter(Mandatory)][string]$Path)
  if ([IO.Path]::IsPathRooted($Path)) {
    return [IO.Path]::GetFullPath($Path)
  }
  [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function New-Utf8NoBomEncoding {
  [Text.UTF8Encoding]::new($false, $true)
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
  $json = ($Value | ConvertTo-Json -Depth 16) +
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

function Require-Command {
  param([Parameter(Mandatory)][string]$Name)
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "required command not found: $Name"
  }
  $command.Source
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$Arguments,
    [Parameter(Mandatory)][string]$LogPath
  )
  @(
    "command=$FilePath $($Arguments -join ' ')",
    "host_time=$(Get-Date -Format o)"
  ) | Out-File $LogPath -Encoding utf8
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    # Native tools such as adb and Gradle commonly emit informational output
    # on stderr. It must remain log data; only the process exit code decides
    # whether this checked command failed.
    $ErrorActionPreference = 'Continue'
    $output = @(
      & $FilePath @Arguments 2>&1 |
        ForEach-Object { $_.ToString() }
    )
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $output | Out-File $LogPath -Append -Encoding utf8
  "exit_code=$exitCode" | Out-File $LogPath -Append -Encoding utf8
  if ($exitCode -ne 0) {
    throw "command failed: $FilePath $($Arguments -join ' ')"
  }
  @($output)
}

function Resolve-RepositoryPath {
  param([Parameter(Mandatory)][string]$Path)
  if ([IO.Path]::IsPathRooted($Path)) {
    return (Resolve-Path $Path).Path
  }
  (Resolve-Path (Join-Path $RepoRoot $Path)).Path
}

function Invoke-Issue60 {
  param([Parameter(Mandatory)][string[]]$Arguments)
  # B1: [CmdletBinding()] 付きスクリプトへ @Arguments を直接スプラットすると
  # 位置引数として扱われ '-Action' が ValidateSet の値として拒否される。
  # powershell.exe -File 経由なら argv として渡され、param() が名前付き
  # パラメータとして正しくパースする。
  & powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File $Issue60Tool `
    @Arguments `
    -Serial $Serial `
    -PackageName $PackageName `
    -OutputRoot $EvidenceRoot
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw (
      "command failed: powershell.exe -File $Issue60Tool " +
      "$($Arguments -join ' ') (exit $exitCode)"
    )
  }
}

function Invoke-Orchestrator {
  param([Parameter(Mandatory)][string[]]$Arguments)
  $python = Require-Command 'python'
  Push-Location $RepoRoot
  try {
    Invoke-Checked `
      -FilePath $python `
      -Arguments (@($Orchestrator) + $Arguments) `
      -LogPath (
        Join-Path $EvidenceRoot 'orchestrator-last-command.txt'
      ) |
      Out-Null
  }
  finally {
    Pop-Location
  }
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

function Refresh-Origin {
  $git = Require-Command 'git'
  Push-Location $RepoRoot
  try {
    Invoke-Checked `
      -FilePath $git `
      -Arguments @('fetch', 'origin') `
      -LogPath (Join-Path $EvidenceRoot 'git-fetch.txt') |
      Out-Null
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

function New-State {
  [pscustomobject][ordered]@{
    schemaVersion = 1
    repository = 'kaenozu/ashita-motsumono'
    applicationId = $PackageName
    serial = $Serial
    evidenceRoot = $EvidenceRoot
    sessionStarted = $false
    sourceSha = ''
    cases = [pscustomobject][ordered]@{
      normal = $null
      reboot = $null
      'install-r' = $null
    }
    updatedAt = Get-Date -Format o
  }
}

function Get-State {
  if (Test-Path $StatePath) {
    return Read-JsonFile $StatePath
  }
  New-State
}

function Save-State {
  param([Parameter(Mandatory)]$State)
  $State.updatedAt = Get-Date -Format o
  Write-JsonFile $State $StatePath
}

function Set-CaseState {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][string]$Type,
    [Parameter(Mandatory)]$Value
  )
  $State.cases |
    Add-Member `
      -NotePropertyName $Type `
      -NotePropertyValue $Value `
      -Force
}

function Get-CaseState {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][string]$Type
  )
  $property = $State.cases.PSObject.Properties[$Type]
  if (-not $property -or -not $property.Value) {
    throw "no planned case for type: $Type"
  }
  $property.Value
}

function Require-Session {
  $state = Get-State
  if (-not $state.sessionStarted -or -not (Test-Path $SessionPath)) {
    throw 'StartSession must succeed before case work'
  }
  $session = Read-JsonFile $SessionPath
  $hostOffset = [TimeZoneInfo]::Local.GetUtcOffset([DateTime]::Now)
  if ($hostOffset -ne [TimeSpan]::FromHours(9)) {
    throw "host UTC offset must be +09:00, got $hostOffset"
  }

  $git = Get-GitGate
  if ($git.gate -ne 'PASS') {
    throw "git gate is $($git.gate)"
  }
  if ($session.sourceSha -ne $git.head) {
    throw 'release session source differs from current HEAD'
  }
  if ($session.sourceSha -ne $git.originMaster) {
    throw 'origin/master moved after release session start'
  }
  [pscustomobject][ordered]@{
    state = $state
    session = $session
    git = $git
  }
}

function Round-UpToMinute {
  param([Parameter(Mandatory)][DateTimeOffset]$Value)
  $rounded = [DateTimeOffset]::new(
    $Value.Year,
    $Value.Month,
    $Value.Day,
    $Value.Hour,
    $Value.Minute,
    0,
    $Value.Offset
  )
  if ($Value.Second -gt 0 -or $Value.Millisecond -gt 0) {
    $rounded = $rounded.AddMinutes(1)
  }
  $rounded
}

function Default-LeadMinutes {
  param([Parameter(Mandatory)][string]$Type)
  switch ($Type) {
    'normal' { 12 }
    'reboot' { 22 }
    'install-r' { 22 }
    default { throw "unsupported case type: $Type" }
  }
}

function Prefix-ForCase {
  param([Parameter(Mandatory)][string]$Type)
  switch ($Type) {
    'normal' { 'NORMAL' }
    'reboot' { 'REBOOT' }
    'install-r' { 'UPDATE' }
    default { throw "unsupported case type: $Type" }
  }
}

function Require-PreviousCase {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][string]$Type
  )
  if ($Type -eq 'reboot') {
    $normal = Get-CaseState $State 'normal'
    if ($normal.verdict -ne 'PASS') {
      throw 'normal case must PASS before reboot'
    }
  }
  elseif ($Type -eq 'install-r') {
    $reboot = Get-CaseState $State 'reboot'
    if ($reboot.verdict -ne 'PASS') {
      throw 'reboot case must PASS before install-r'
    }
  }
}

function Doctor {
  foreach ($name in @('git', 'python', 'flutter', 'adb')) {
    Require-Command $name | Out-Null
  }

  if (-not (Test-Path $SessionPath)) {
    Refresh-Origin
  }

  $hostOffset = [TimeZoneInfo]::Local.GetUtcOffset([DateTime]::Now)
  if ($hostOffset -ne [TimeSpan]::FromHours(9)) {
    throw "host UTC offset must be +09:00, got $hostOffset"
  }

  $git = Get-GitGate
  if ($git.gate -ne 'PASS') {
    throw "git gate is $($git.gate)"
  }
  if (Test-Path $SessionPath) {
    $session = Read-JsonFile $SessionPath
    if ($session.sourceSha -ne $git.head) {
      throw 'existing release session differs from current HEAD'
    }
  }

  Invoke-Issue60 @(
    '-Action', 'Preflight',
    '-CaseName', 'SETUP_ENV'
  )
  $preflightPath = Join-Path (
    Join-Path $EvidenceRoot 'SETUP_ENV'
  ) 'preflight-result.json'
  $preflight = Read-JsonFile $preflightPath
  if ($preflight.Result -ne 'PASS') {
    throw "environment preflight is $($preflight.Result)"
  }

  $result = [pscustomobject][ordered]@{
    result = 'PASS'
    checkedAt = Get-Date -Format o
    git = $git
    emulator = $preflight
    hostUtcOffset = $hostOffset.ToString()
    releaseSessionStarted = (Test-Path $SessionPath)
  }
  Write-JsonFile `
    $result `
    (Join-Path $EvidenceRoot 'release-validation-doctor.json')
  $result
}

function Build-Install {
  if (Test-Path $SessionPath) {
    throw 'BuildInstall must run before StartSession'
  }
  Doctor | Out-Null

  $flutter = Require-Command 'flutter'
  Push-Location $RepoRoot
  try {
    Invoke-Checked `
      -FilePath $flutter `
      -Arguments @('pub', 'get') `
      -LogPath (Join-Path $EvidenceRoot 'flutter-pub-get.txt') |
      Out-Null
    Invoke-Checked `
      -FilePath $flutter `
      -Arguments @('build', 'apk', '--debug') `
      -LogPath (
        Join-Path $EvidenceRoot 'flutter-build-debug-apk.txt'
      ) |
      Out-Null
  }
  finally {
    Pop-Location
  }

  $resolvedApk = Resolve-RepositoryPath $ApkPath
  Invoke-Issue60 @(
    '-Action', 'Install',
    '-CaseName', 'SETUP_INSTALL',
    '-CaseType', 'setup',
    '-ApkPath', $resolvedApk
  )

  Write-Host ''
  Write-Host 'NEXT HUMAN ACTION:'
  Write-Host '1. Open the app once on emulator-5554.'
  Write-Host '2. Grant notification permission.'
  Write-Host '3. Return Home.'
  Write-Host '4. Run StartSession.'
}

function Start-ReleaseSession {
  Doctor | Out-Null

  Invoke-Issue60 @(
    '-Action', 'Preflight',
    '-CaseName', 'SETUP_APP',
    '-RequireInstalledApp'
  )
  $preflightPath = Join-Path (
    Join-Path $EvidenceRoot 'SETUP_APP'
  ) 'preflight-result.json'
  $preflight = Read-JsonFile $preflightPath
  if (
    $preflight.Result -ne 'PASS' -or
    $preflight.Permission -ne 'GRANTED'
  ) {
    throw (
      'installed-app preflight or notification permission ' +
      'is not PASS'
    )
  }

  if (-not (Test-Path $SessionPath)) {
    Invoke-Orchestrator @(
      'start-session',
      '--root', $RepoRoot,
      '--output', $SessionPath
    )
  }
  $session = Read-JsonFile $SessionPath
  $git = Get-GitGate
  if ($session.sourceSha -ne $git.head) {
    throw 'existing release session differs from current HEAD'
  }

  $state = Get-State
  $state.sessionStarted = $true
  $state.sourceSha = [string]$session.sourceSha
  Save-State $state

  Write-Host "release session fixed to $($session.sourceSha)"
  Write-Host (
    'Do not merge another PR until Issue #60 ' +
    'aggregation completes.'
  )
}

function Plan-Case {
  $context = Require-Session
  $state = $context.state
  Require-PreviousCase $state $CaseType

  $lead = if ($LeadMinutes -gt 0) {
    $LeadMinutes
  }
  else {
    Default-LeadMinutes $CaseType
  }
  if ($lead -lt 5) {
    throw 'LeadMinutes must be at least 5'
  }

  $expected = if ($ExpectedTime) {
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse(
        $ExpectedTime,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
      )) {
      throw 'ExpectedTime must be ISO 8601'
    }
    Round-UpToMinute $parsed
  }
  else {
    Round-UpToMinute ([DateTimeOffset]::Now.AddMinutes($lead))
  }
  if ($expected -le [DateTimeOffset]::Now.AddMinutes(4)) {
    throw 'ExpectedTime must be at least 4 minutes in the future'
  }

  $prefix = Prefix-ForCase $CaseType
  $caseName = '{0}_{1}_{2}' -f (
    $prefix,
    $expected.ToString('yyyyMMdd_HHmm'),
    (Get-Date -Format 'ss')
  )
  $plan = [pscustomobject][ordered]@{
    caseType = $CaseType
    caseName = $caseName
    todoTitle = $caseName
    expectedTime = $expected.ToString('o')
    sourceSha = [string]$context.session.sourceSha
    status = 'PLANNED'
    verdict = ''
    plannedAt = Get-Date -Format o
  }

  Invoke-Issue60 @(
    '-Action', 'PlanCase',
    '-CaseName', $caseName,
    '-CaseType', $CaseType,
    '-TodoTitle', $caseName,
    '-ExpectedTime', $plan.expectedTime
  )

  Set-CaseState $state $CaseType $plan
  Save-State $state
  Write-JsonFile `
    $plan `
    (Join-Path $EvidenceRoot "planned-$CaseType.json")

  Write-Host ''
  Write-Host 'CREATE THIS TODO ON THE EMULATOR:'
  Write-Host "Title: $($plan.todoTitle)"
  Write-Host "Expected notification: $($plan.expectedTime)"
  Write-Host (
    "Enter local time: $($expected.ToString('yyyy-MM-dd HH:mm zzz'))"
  )
  Write-Host 'Enable same-day notification only.'
  Write-Host 'Save, immediately go Home, and do not reopen the app.'
  Write-Host "Then run BeginCase -CaseType $CaseType."
}

function Begin-Case {
  $context = Require-Session
  $case = Get-CaseState $context.state $CaseType
  if ($case.status -ne 'PLANNED') {
    throw "case status must be PLANNED, got $($case.status)"
  }

  Invoke-Issue60 @(
    '-Action', 'BeginCase',
    '-CaseName', [string]$case.caseName,
    '-CaseType', $CaseType,
    '-TodoTitle', [string]$case.todoTitle,
    '-ExpectedTime', [string]$case.expectedTime
  )

  $case.status = 'BEGUN'
  Set-CaseState $context.state $CaseType $case
  Save-State $context.state

  $registrationPath = Join-Path (
    Join-Path $EvidenceRoot $case.caseName
  ) 'alarm-registration.json'
  $registration = Read-JsonFile $registrationPath
  if ($registration.Result -ne 'PASS') {
    Write-Warning 'No new alarm registration delta was detected.'
    Write-Warning (
      'Do not wait for notification. Review the Todo settings ' +
      'and finalize as INCONCLUSIVE.'
    )
  }
  $registration
}

function Mutate-Case {
  $context = Require-Session
  $case = Get-CaseState $context.state $CaseType
  if ($case.status -ne 'BEGUN') {
    throw 'BeginCase must complete before MutateCase'
  }

  if ($CaseType -eq 'normal') {
    throw 'normal case has no mutation'
  }
  if ($CaseType -eq 'reboot') {
    Invoke-Issue60 @(
      '-Action', 'Reboot',
      '-CaseName', [string]$case.caseName,
      '-CaseType', 'reboot',
      '-TodoTitle', [string]$case.todoTitle,
      '-ExpectedTime', [string]$case.expectedTime,
      '-ResetLogcatBeforeMutation'
    )
  }
  elseif ($CaseType -eq 'install-r') {
    $resolvedApk = Resolve-RepositoryPath $ApkPath
    Invoke-Issue60 @(
      '-Action', 'Install',
      '-CaseName', [string]$case.caseName,
      '-CaseType', 'install-r',
      '-TodoTitle', [string]$case.todoTitle,
      '-ExpectedTime', [string]$case.expectedTime,
      '-ApkPath', $resolvedApk,
      '-ResetLogcatBeforeMutation'
    )
  }

  $case.status = 'MUTATED'
  Set-CaseState $context.state $CaseType $case
  Save-State $context.state
}

function Wait-Case {
  $context = Require-Session
  $case = Get-CaseState $context.state $CaseType
  $allowed = if ($CaseType -eq 'normal') {
    @('BEGUN', 'WAITED')
  }
  else {
    @('MUTATED', 'WAITED')
  }
  if ($case.status -notin $allowed) {
    throw "case status $($case.status) is not ready for WaitCase"
  }

  Invoke-Issue60 @(
    '-Action', 'Wait',
    '-CaseName', [string]$case.caseName,
    '-CaseType', $CaseType,
    '-TodoTitle', [string]$case.todoTitle
  )

  $case.status = 'WAITED'
  Set-CaseState $context.state $CaseType $case
  Save-State $context.state
}

function Finalize-Case {
  $context = Require-Session
  $case = Get-CaseState $context.state $CaseType
  if (-not $Verdict) {
    throw 'Verdict is required for FinalizeCase'
  }

  $arguments = @(
    '-Action', 'Finalize',
    '-CaseName', [string]$case.caseName,
    '-CaseType', $CaseType,
    '-TodoTitle', [string]$case.todoTitle,
    '-Verdict', $Verdict,
    '-Notes', $Notes
  )
  if ($ManualScreenshotVerified) {
    $arguments += '-ManualScreenshotVerified'
  }
  if ($InstallBroadcastVerified) {
    $arguments += '-InstallBroadcastVerified'
  }
  if ($InstallBroadcastUnverified) {
    $arguments += '-InstallBroadcastUnverified'
  }
  Invoke-Issue60 $arguments

  $resultPath = Join-Path (
    Join-Path $EvidenceRoot $case.caseName
  ) 'case-result.json'
  $result = Read-JsonFile $resultPath
  $case.status = 'FINALIZED'
  $case.verdict = [string]$result.Verdict
  $case | Add-Member -NotePropertyName 'resultPath' -NotePropertyValue $resultPath -Force
  Set-CaseState $context.state $CaseType $case
  Save-State $context.state
  $result
}

function Evaluate-Release {
  param([switch]$AsReportOnly)

  Refresh-Origin
  Require-Session | Out-Null
  $arguments = @(
    'evaluate',
    '--root', $RepoRoot,
    '--session', $SessionPath,
    '--output-json', $ReadinessJsonPath,
    '--output-markdown', $ReadinessMarkdownPath
  )

  $issueSummaryPath = Join-Path (
    Join-Path $EvidenceRoot 'ISSUE60_SUMMARY'
  ) 'issue60-summary.json'
  if (Test-Path $issueSummaryPath) {
    $arguments += @('--issue60-summary', $issueSummaryPath)
  }
  if (Test-Path $PlayEvidencePath) {
    $arguments += @(
      '--play-console-evidence',
      $PlayEvidencePath
    )
  }
  if (Test-Path $ManifestPath) {
    $arguments += @('--release-manifest', $ManifestPath)
  }
  if (Test-Path $InternalEvidencePath) {
    $arguments += @(
      '--internal-test-evidence',
      $InternalEvidencePath
    )
  }
  if ($AsReportOnly) {
    $arguments += '--report-only'
  }

  Invoke-Orchestrator $arguments
  Read-JsonFile $ReadinessJsonPath
}

function Aggregate-Cases {
  Refresh-Origin
  $context = Require-Session
  $normal = Get-CaseState $context.state 'normal'
  $reboot = Get-CaseState $context.state 'reboot'
  $install = Get-CaseState $context.state 'install-r'
  foreach ($case in @($normal, $reboot, $install)) {
    if ($case.status -ne 'FINALIZED') {
      throw "case $($case.caseName) is not FINALIZED"
    }
  }

  Invoke-Issue60 @(
    '-Action', 'Aggregate',
    '-CaseName', 'ISSUE60_SUMMARY',
    '-NormalCaseName', [string]$normal.caseName,
    '-RebootCaseName', [string]$reboot.caseName,
    '-InstallCaseName', [string]$install.caseName
  )

  Evaluate-Release -AsReportOnly | Out-Null
  Read-JsonFile (
    Join-Path (
      Join-Path $EvidenceRoot 'ISSUE60_SUMMARY'
    ) 'issue60-summary.json'
  )
}

function Write-Templates {
  $context = Require-Session
  if (-not (Test-Path $PlayEvidencePath)) {
    Invoke-Orchestrator @(
      'write-template',
      '--kind', 'play-console',
      '--output', $PlayEvidencePath
    )
  }
  if (-not (Test-Path $InternalEvidencePath)) {
    Invoke-Orchestrator @(
      'write-template',
      '--kind', 'internal-test',
      '--source-sha', [string]$context.session.sourceSha,
      '--output', $InternalEvidencePath
    )
  }
  Write-Host "play evidence: $PlayEvidencePath"
  Write-Host "internal-test evidence: $InternalEvidencePath"
}

function Show-Status {
  $git = Get-GitGate
  $state = Get-State
  $report = if (Test-Path $ReadinessJsonPath) {
    Read-JsonFile $ReadinessJsonPath
  }
  else {
    $null
  }
  $next = if (-not $state.sessionStarted) {
    'BuildInstall, grant notification permission, then StartSession'
  }
  elseif (-not $state.cases.normal) {
    'PlanCase -CaseType normal'
  }
  elseif ($state.cases.normal.verdict -ne 'PASS') {
    'complete or repeat the normal case'
  }
  elseif (-not $state.cases.reboot) {
    'PlanCase -CaseType reboot'
  }
  elseif ($state.cases.reboot.verdict -ne 'PASS') {
    'complete the reboot case'
  }
  elseif (-not $state.cases.'install-r') {
    'PlanCase -CaseType install-r'
  }
  elseif ($state.cases.'install-r'.status -ne 'FINALIZED') {
    'complete the install-r case'
  }
  else {
    'Aggregate'
  }
  [pscustomobject][ordered]@{
    git = $git
    state = $state
    readiness = $report
    nextCommand = $next
  }
}

switch ($Action) {
  'Doctor' {
    Doctor
  }
  'BuildInstall' {
    Build-Install
  }
  'StartSession' {
    Start-ReleaseSession
  }
  'PlanCase' {
    Plan-Case
  }
  'BeginCase' {
    Begin-Case
  }
  'MutateCase' {
    Mutate-Case
  }
  'WaitCase' {
    Wait-Case
  }
  'FinalizeCase' {
    Finalize-Case
  }
  'Aggregate' {
    Aggregate-Cases
  }
  'WriteTemplates' {
    Write-Templates
  }
  'Evaluate' {
    Evaluate-Release -AsReportOnly:$ReportOnly
  }
  'Status' {
    Show-Status
  }
}
