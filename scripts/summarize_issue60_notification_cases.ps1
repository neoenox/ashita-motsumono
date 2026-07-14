# scripts/summarize_issue60_notification_cases.ps1
# Issue #60 通知実測テストの3ケース結果を集約し、JSONサマリーを生成する。
# run_issue60_notification_cases.ps1 から呼ばれる。
# 関連: run_issue60_notification_cases.ps1, integration_test/issue60_notification_test.dart

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$evidenceDir = 'C:\Users\neoen\Documents\ashita-release-evidence\issue60'

# ヘルパー: 通知件数をカウント
function Count-Notifications($filePath, $pattern) {
    if (-not (Test-Path $filePath)) { return -1 }
    $lines = Select-String -Path $filePath -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
    if ($null -eq $lines) { return 0 }
    return $lines.Count
}

# 各ケースの結果を集計
$case1 = @{
    case     = 'normal'
    keyword  = 'テスト持ち物'
    count    = (Count-Notifications "$evidenceDir\case1_notifications.txt" 'テスト持ち物')
    verdict  = 'UNKNOWN'
}
$case2 = @{
    case     = 'reboot'
    keyword  = 'テスト再起動'
    count    = (Count-Notifications "$evidenceDir\case2_notifications.txt" 'テスト再起動')
    verdict  = 'UNKNOWN'
}
$case3 = @{
    case     = 'install-r'
    keyword  = 'テスト再インストール'
    count    = (Count-Notifications "$evidenceDir\case3_notifications.txt" 'テスト再インストール')
    verdict  = 'UNKNOWN'
}

# Verdict 判定
foreach ($c in @($case1, $case2, $case3)) {
    if ($c.count -gt 0) {
        $c.verdict = 'PASS'
    } else {
        $c.verdict = 'FAIL'
    }
}

# JSON サマリー生成
$summary = @{
    issue      = 60
    title      = 'Todo追加時の通知実測テスト'
    timestamp  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    evidence   = $evidenceDir
    cases      = @($case1, $case2, $case3)
    overall    = 'UNKNOWN'
}

# 全ケースPASSなら PASS
$allPass = $true
foreach ($c in $summary.cases) {
    if ($c.verdict -ne 'PASS') {
        $allPass = $false
        break
    }
}
$summary.overall = if ($allPass) { 'PASS' } else { 'FAIL' }

# JSON ファイル出力
$jsonPath = "$evidenceDir\issue60-summary.json"
$summary | ConvertTo-Json -Depth 5 | Out-File $jsonPath -Encoding UTF8
Write-Host "Summary: $jsonPath"

# テキストサマリー出力
Write-Host ''
Write-Host '============================='
Write-Host ' Issue #60 通知実測テスト結果'
Write-Host '============================='
foreach ($c in $summary.cases) {
    $icon = if ($c.verdict -eq 'PASS') { '✅' } else { '❌' }
    Write-Host "  $icon $($c.case): $($c.count) 件 (verdict=$($c.verdict))"
}
Write-Host ''
Write-Host "Overall: $($summary.overall)"
Write-Host '============================='
