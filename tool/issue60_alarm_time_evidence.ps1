[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$BeforeAlarmPath,
  [Parameter(Mandatory)][string]$AfterAlarmPath,
  [Parameter(Mandatory)][string]$ExpectedTime,
  [Parameter(Mandatory)][string]$Destination,
  [string]$PackageName = 'com.ashita_motsumono',
  [int]$ToleranceMinutes = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PackageName -ne 'com.ashita_motsumono') {
  throw 'package must be com.ashita_motsumono'
}
if ($ToleranceMinutes -lt 1 -or $ToleranceMinutes -gt 30) {
  throw 'ToleranceMinutes must be 1..30'
}

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
  $json = ($Value | ConvertTo-Json -Depth 16) +
    [Environment]::NewLine
  [IO.File]::WriteAllText(
    $fullPath,
    $json,
    (New-Utf8NoBomEncoding)
  )
}

function Parse-IsoTime {
  param(
    [Parameter(Mandatory)][string]$Value,
    [Parameter(Mandatory)][string]$Name
  )
  $parsed = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse(
      $Value,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind,
      [ref]$parsed
    )) {
    throw "$Name must be ISO 8601"
  }
  $parsed
}

function Get-UnixMilliseconds {
  param([Parameter(Mandatory)][DateTimeOffset]$Value)
  $epoch = [DateTimeOffset]::new(
    1970,
    1,
    1,
    0,
    0,
    0,
    [TimeSpan]::Zero
  )
  [long](($Value.ToUniversalTime() - $epoch).TotalMilliseconds)
}

function Convert-TimeCandidate {
  param(
    [Parameter(Mandatory)][string]$Value,
    [Parameter(Mandatory)][TimeSpan]$DefaultOffset,
    [Parameter(Mandatory)][string]$SourceLine
  )
  $candidate = $null
  if ($Value -match '^\d{13}$') {
    $epoch = [DateTimeOffset]::new(
      1970,
      1,
      1,
      0,
      0,
      0,
      [TimeSpan]::Zero
    )
    $candidate = $epoch.AddMilliseconds([double]$Value)
  }
  elseif ($Value -match '^\d{10}$') {
    $epoch = [DateTimeOffset]::new(
      1970,
      1,
      1,
      0,
      0,
      0,
      [TimeSpan]::Zero
    )
    $candidate = $epoch.AddSeconds([double]$Value)
  }
  else {
    $normalized = $Value.Trim().Replace('/', '-')
    if ($normalized -notmatch '(Z|[+-]\d{2}:?\d{2})$') {
      $sign = if ($DefaultOffset -lt [TimeSpan]::Zero) {
        '-'
      }
      else {
        '+'
      }
      $absolute = $DefaultOffset.Duration()
      $offsetText = '{0}{1:00}:{2:00}' -f (
        $sign,
        $absolute.Hours,
        $absolute.Minutes
      )
      $normalized = "$normalized$offsetText"
    }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse(
        $normalized,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
      )) {
      $candidate = $parsed
    }
  }
  if ($null -eq $candidate) {
    return $null
  }
  [pscustomobject][ordered]@{
    epochMilliseconds = Get-UnixMilliseconds $candidate
    iso = $candidate.ToString('o')
    sourceLine = $SourceLine.Trim()
  }
}

function Get-TimeCandidates {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][DateTimeOffset]$Expected
  )
  if (-not (Test-Path $Path)) {
    return @()
  }
  $lines = @(Get-Content -Encoding utf8 $Path)
  $relevantIndices = [System.Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = [string]$lines[$index]
    if (
      $line -match [regex]::Escape($PackageName) -or
      $line -match 'ScheduledNotificationReceiver' -or
      $line -match 'flutterlocalnotifications'
    ) {
      $relevantIndices.Add($index)
    }
  }

  $seen = @{}
  $results = [System.Collections.Generic.List[object]]::new()
  foreach ($index in $relevantIndices) {
    $start = [Math]::Max(0, $index - 20)
    $end = [Math]::Min($lines.Count - 1, $index + 20)
    for ($lineIndex = $start; $lineIndex -le $end; $lineIndex++) {
      $sourceLine = [string]$lines[$lineIndex]
      $values = [System.Collections.Generic.List[string]]::new()
      foreach ($match in [regex]::Matches(
          $sourceLine,
          '(?i)\b(?:origWhen|when)\s*=\s*(\d{10,13})\b'
        )) {
        $values.Add([string]$match.Groups[1].Value)
      }
      foreach ($match in [regex]::Matches(
          $sourceLine,
          '(?<!\d)(20\d{2}[-/]\d{2}[-/]\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)'
        )) {
        $values.Add([string]$match.Groups[1].Value)
      }
      foreach ($value in $values) {
        $candidate = Convert-TimeCandidate `
          -Value $value `
          -DefaultOffset $Expected.Offset `
          -SourceLine $sourceLine
        if ($null -eq $candidate) {
          continue
        }
        $key = [string]$candidate.epochMilliseconds
        if (-not $seen.ContainsKey($key)) {
          $seen[$key] = $true
          $results.Add($candidate)
        }
      }
    }
  }
  @($results | Sort-Object epochMilliseconds)
}

$beforePath = Get-FullPath $BeforeAlarmPath
$afterPath = Get-FullPath $AfterAlarmPath
if (-not (Test-Path $beforePath)) {
  throw "missing before alarm dump: $beforePath"
}
if (-not (Test-Path $afterPath)) {
  throw "missing after alarm dump: $afterPath"
}

$expected = Parse-IsoTime $ExpectedTime 'ExpectedTime'
$before = @(Get-TimeCandidates -Path $beforePath -Expected $expected)
$after = @(Get-TimeCandidates -Path $afterPath -Expected $expected)
$beforeKeys = @{}
foreach ($candidate in $before) {
  $beforeKeys[[string]$candidate.epochMilliseconds] = $true
}
$added = @(
  $after | Where-Object {
    -not $beforeKeys.ContainsKey([string]$_.epochMilliseconds)
  }
)
$expectedEpoch = Get-UnixMilliseconds $expected
$matching = @(
  $added | Where-Object {
    [Math]::Abs(
      [double]$_.epochMilliseconds - [double]$expectedEpoch
    ) -le ($ToleranceMinutes * 60 * 1000)
  }
)
$resultName = if ($added.Count -eq 0) {
  'INCONCLUSIVE'
}
elseif ($matching.Count -gt 0) {
  'PASS'
}
else {
  'MISMATCH'
}

$result = [pscustomobject][ordered]@{
  result = $resultName
  expectedTime = $expected.ToString('o')
  toleranceMinutes = $ToleranceMinutes
  beforeCandidates = @($before)
  afterCandidates = @($after)
  addedCandidates = @($added)
  matchingCandidates = @($matching)
  parserPolicy = 'Only package-adjacent wall-clock or Unix timestamps are accepted.'
  unparseablePolicy = 'INCONCLUSIVE'
  mismatchPolicy = 'INCONCLUSIVE_FOR_CASE'
  generatedAt = Get-Date -Format o
}
Write-JsonFile $result $Destination
$result
