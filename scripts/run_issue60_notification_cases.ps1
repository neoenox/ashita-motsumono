# scripts/run_issue60_notification_cases.ps1
# Issue #60 通知実測テストを3ケース実行し、エビデンスを集約する。
# 事前条件: エミュレータ起動、adb接続、flutter build apk --debug 完了済み。
# 関連: integration_test/issue60_notification_test.dart, summarize_issue60_notification_cases.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$adb = 'C:\Android\sdk\platform-tools\adb.exe'
$projectDir = 'C:\gemini-desktop\ashita-motsumono'
$evidenceDir = 'C:\Users\neoen\Documents\ashita-release-evidence\issue60'

# 証拠ディレクトリ作成
if (-not (Test-Path $evidenceDir)) {
    New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
}

Write-Host '=== Issue #60 通知実測テスト開始 ==='

# プレファイアンス: 現在の通知ダンプを保存
Write-Host '[Preflight] 通知ダンプ保存...'
& $adb shell dumpsys notification --noredact | Out-File "$evidenceDir\preflight_notifications.txt"

# Case1: 通常テスト
Write-Host ''
Write-Host '[Case 1/3] Normal テスト実行中...'
Push-Location $projectDir
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/issue60_notification_test.dart --flavor="" -d emulator 2>&1 | Out-File "$evidenceDir\case1_output.txt"
Pop-Location

# Case1結果確認
Write-Host '[Case 1/3] 通知確認...'
& $adb shell dumpsys notification --noredact | Out-File "$evidenceDir\case1_notifications.txt"
$case1Count = (Select-String -Path "$evidenceDir\case1_notifications.txt" -Pattern "テスト持ち物" -SimpleMatch).Count
Write-Host "  通知件数: $case1Count"

# Case2: 再起動テスト（別セッションで実行）
Write-Host ''
Write-Host '[Case 2/3] Reboot テスト実行中...'
Push-Location $projectDir
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/issue60_notification_test.dart -d emulator 2>&1 | Out-File "$evidenceDir\case2_output.txt"
Pop-Location

# 再起動実行
Write-Host '  デバイス再起動中...'
& $adb reboot
Start-Sleep -Seconds 35

# 起動待ち
for ($i = 0; $i -lt 20; $i++) {
    $boot = & $adb shell getprop sys.boot_completed 2>&1
    if ($boot.Trim() -eq '1') { break }
    Start-Sleep -Seconds 5
}

Write-Host '[Case 2/3] 再起動後通知確認...'
& $adb shell dumpsys notification --noredact | Out-File "$evidenceDir\case2_notifications.txt"
$case2Count = (Select-String -Path "$evidenceDir\case2_notifications.txt" -Pattern "テスト再起動" -SimpleMatch).Count
Write-Host "  通知件数: $case2Count"

# Case3: 再インストールテスト
Write-Host ''
Write-Host '[Case 3/3] Install-r テスト実行中...'
Push-Location $projectDir
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/issue60_notification_test.dart -d emulator 2>&1 | Out-File "$evidenceDir\case3_output.txt"
Pop-Location

# APKビルド & 再インストール
Write-Host '  APK ビルド中...'
Push-Location $projectDir
flutter build apk --debug 2>&1 | Out-File "$evidenceDir\case3_build.txt"
Pop-Location

Write-Host '  再インストール中...'
& $adb install -r "$projectDir\build\app\outputs\flutter-apk\app-debug.apk" | Out-File "$evidenceDir\case3_install.txt"
Start-Sleep -Seconds 5

Write-Host '[Case 3/3] 再インストール後通知確認...'
& $adb shell dumpsys notification --noredact | Out-File "$evidenceDir\case3_notifications.txt"
$case3Count = (Select-String -Path "$evidenceDir\case3_notifications.txt" -Pattern "テスト再インストール" -SimpleMatch).Count
Write-Host "  通知件数: $case3Count"

# 集約サマリー生成
Write-Host ''
Write-Host '=== サマリー生成 ==='
& "$PSScriptRoot\summarize_issue60_notification_cases.ps1"

Write-Host ''
Write-Host '=== 全ケース完了 ==='
Write-Host "証拠ディレクトリ: $evidenceDir"
