Set-StrictMode -Version Latest

function Resolve-Issue60RepositoryRoot {
  param([Parameter(Mandatory)][string]$ScriptDirectory)

  (Resolve-Path (Join-Path $ScriptDirectory '..')).Path
}

function Resolve-Issue60RepositoryPath {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$RepositoryRoot
  )

  if ([IO.Path]::IsPathRooted($Path)) {
    return [IO.Path]::GetFullPath($Path)
  }

  [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $Path))
}

function Resolve-Issue60AdbExecutable {
  $command = Get-Command adb -CommandType Application -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  foreach ($sdkRoot in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)) {
    if (-not $sdkRoot) {
      continue
    }

    foreach ($relativePath in @(
        'platform-tools\adb.exe',
        'platform-tools/adb'
      )) {
      $candidate = Join-Path $sdkRoot $relativePath
      if (Test-Path $candidate -PathType Leaf) {
        return (Resolve-Path $candidate).Path
      }
    }
  }

  throw 'adb not found in PATH, ANDROID_SDK_ROOT, or ANDROID_HOME'
}
