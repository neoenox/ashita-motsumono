# Android Release Execution Plan

対象リポジトリ：`kaenozu/ashita-motsumono`  
正式アプリ名：`あしたもつもの`  
Application ID：`com.ashita_motsumono`

この文書は、Android通知実測からGoogle Play提出までの唯一の実行順を定義します。各段階の静的確認やCI成功を、後続段階の実測PASSとして代用しません。

## 1. 判定原則

- 作業順は **Issue #60 → Issue #98 → Issue #59 → Issue #94** とする。
- Issue #60の3ケースが終わるまで、検証対象`master`を実質的に凍結する。
- 3ケースのSource SHAは同一で、集約時点の最新`origin/master`と一致させる。
- Android 13以降の通知実測は、`POST_NOTIFICATIONS`が許可済みであることを前提にする。
- Play Console、GitHub Actions、APK/AAB、内部テストの証跡は同一Source SHAと正式Run IDで関連付ける。
- 証跡が不足する場合は`PASS`にせず、`BLOCKED`または`INCONCLUSIVE`とする。
- Secrets、キーストア、パスワード、AdMob ID、Gemini Proxy URLは証跡JSONへ記録しない。

公式資料：

- Android通知ランタイム権限：<https://developer.android.com/develop/ui/views/notifications/notification-permission>
- Play App Signing：<https://support.google.com/googleplay/android-developer/answer/9842756>
- Google Play内部テスト：<https://support.google.com/googleplay/android-developer/answer/9845334>

## 2. Release sessionを開始する

短いworktreeを最新`origin/master`から作成します。

```powershell
git fetch origin
git worktree add C:\wt\release origin/master
cd C:\wt\release
```

検証対象SHAを固定します。

```powershell
$evidence = Join-Path $HOME 'Documents\ashita-release-evidence'
New-Item -ItemType Directory -Force $evidence | Out-Null

python .\tool\release_execution_gate.py start-session `
  --root . `
  --output "$evidence\release-session.json"
```

`start-session`は次を満たさなければ失敗します。

- `HEAD == origin/master`
- 追跡対象ファイルにローカル変更がない
- リポジトリ、Application ID、Source SHAを記録できる

`release-session.json`作成後、Issue #60の集約が終わるまで別PRを`master`へマージしません。`origin/master`が動いた場合、統合ゲートはRelease sessionを`BLOCKED`にします。

## 3. Issue #60：Android Emulator通知実測

`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md`に従い、`emulator-5554`で次を実測します。

1. 通常状態
2. Emulator再起動後
3. `adb install -r`後

対象は常に次へ固定します。

- Emulator：`emulator-5554`
- Application ID：`com.ashita_motsumono`
- Source：`release-session.json`の`sourceSha`

3ケース終了後に集約します。

```powershell
.\tool\issue60_emulator_evidence.ps1 `
  -Action Aggregate `
  -CaseName ISSUE60_SUMMARY `
  -NormalCaseName NORMAL_HHMM `
  -RebootCaseName REBOOT_HHMM `
  -InstallCaseName UPDATE_HHMM
```

統合ゲートが受け入れる最低条件：

- `Recommendation=ELIGIBLE_FOR_CLOSE_REVIEW`
- Normal：`PASS`
- Reboot：`PASS`
- install-r：
  - `MY_PACKAGE_REPLACED`を明示確認した`PASS`、または
  - 通知到着、タイトル、通知領域画面、Notification dumpが揃い、broadcast因果関係だけを未確認とした`INCONCLUSIVE`
- 3ケースがRelease sessionと同じSource SHA

この段階でIssue #60をCloseレビューし、`issue60-summary.json`を以後のRelease証跡として保存します。

## 4. Issue #98：Play Consoleとアップロード証明書

Play Consoleでアプリを作成し、Play App Signingを設定します。アップロード証明書SHA-256を記録し、GitHub Actionsで使用する本番アップロード鍵と一致させます。

証跡テンプレートを作成します。

```powershell
python .\tool\release_execution_gate.py write-template `
  --kind play-console `
  --output "$evidence\play-console-evidence.json"
```

Play Consoleで確認した事実だけを`true`に変更します。必須項目：

- アプリ作成済み
- アプリ名が「あしたもつもの」
- Application IDが`com.ashita_motsumono`
- デフォルト言語が日本語
- プライバシーポリシー登録済み
- Play App Signing設定済み
- アップロード証明書SHA-256記録済み
- ストア掲載、データセーフティ、コンテンツレーティング、広告申告が完了
- 広告削除商品を作成し、商品IDを記録

`CN=Test`の証明書を本番鍵と推測しません。Play Consoleのアップロード証明書と一致しない場合、正式Releaseへ進みません。

## 5. Issue #59：正式Release Android Run

GitHub SecretsとRepository Variablesを登録後、`Release Android`を`workflow_dispatch`または正式`v*`タグで実行します。

必須Secrets：

- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`
- `GEMINI_PROXY_URL`

必須Repository Variable：

- `ANDROID_UPLOAD_CERT_SHA256`

商品IDを`remove_ads`以外にする場合：

- `IAP_REMOVE_ADS_PRODUCT_ID`

正式Runから次を保存します。

- `ashita-motsumono-signed-release-apk`
- `ashita-motsumono-signed-release-aab`
- `ashita-motsumono-release-evidence`
- `release-manifest.json`

統合ゲートは`release-manifest.json`について次を強制します。

- commit SHAがRelease sessionと一致
- Application IDが一致
- Play Console、キーストア、APK、AABの証明書SHA-256が一致
- 3つの証明書照合がすべて`matches: true`
- APK/AABのSHA-256が64桁の有効値
- artifact名が正式名称と一致
- 課金商品IDがPlay Console証跡と一致
- GitHub Actions Run IDが正の整数

## 6. Issue #94：内部テストと実機スモークテスト

正式AABをGoogle Play内部テストへアップロードし、Play Store経由でインストールします。ローカルAPKの直接インストールだけでは内部テストPASSにしません。

テンプレートを作成します。

```powershell
$sourceSha = (Get-Content "$evidence\release-session.json" -Raw |
  ConvertFrom-Json).sourceSha

python .\tool\release_execution_gate.py write-template `
  --kind internal-test `
  --source-sha $sourceSha `
  --output "$evidence\internal-test-evidence.json"
```

次をすべて確認します。

- AABを内部テストへアップロード
- テスターアカウントでPlay Store経由インストール
- カメラ撮影、画像選択、日本語OCR
- OCR・AI解析失敗時の手入力フォールバック
- 通知表示
- 通知拒否時もTodo登録可能
- 本番AdMob広告表示
- 広告読み込み失敗時も主要機能利用可能
- 広告削除商品の価格表示、購入、広告非表示
- 購入復元
- AI画像解析の同意、購入、実行
- 全データ削除
- JSONエクスポート

`internal-test-evidence.json`の`sourceSha`と`releaseRunId`は、Release sessionおよび`release-manifest.json`と一致させます。

## 7. 統合判定

すべての証跡が揃ったら実行します。

```powershell
python .\tool\release_execution_gate.py evaluate `
  --root . `
  --session "$evidence\release-session.json" `
  --issue60-summary "$evidence\ISSUE60_SUMMARY\issue60-summary.json" `
  --play-console-evidence "$evidence\play-console-evidence.json" `
  --release-manifest "$evidence\release-manifest.json" `
  --internal-test-evidence "$evidence\internal-test-evidence.json" `
  --output-json "$evidence\release-readiness.json" `
  --output-markdown "$evidence\release-readiness.md"
```

途中経過だけを出力する場合は`--report-only`を付けます。証跡不足があっても報告ファイルを生成しますが、判定は`KEEP_BLOCKED`のままです。

提出可能な最終判定：

```text
READY_FOR_SUBMISSION
```

それ以外は審査提出しません。

## 8. Issue更新と提出

`release-readiness.md`をIssue #94へ記録し、Issue #60、#98、#59の各完了証跡と相互参照します。

`READY_FOR_SUBMISSION`確認後にのみ：

1. Play Consoleの必須警告がないことを再確認
2. 審査提出
3. 公開URL取得
4. LP側へGoogle Play URL反映
5. Issue #94をClose

## 9. 自動化できない作業

次は認証済みの外部環境で人間が実行します。

- ユーザーPC上の`emulator-5554`操作
- 通知領域の目視確認
- Play Consoleアプリ作成とフォーム入力
- 本番アップロード鍵の作成・安全な保管
- GitHub Secrets／Variablesの値登録
- Play内部テストの配布と実機操作
- AdMob、課金、Gemini Proxyの本番環境確認
- 審査提出

統合ゲートはこれらを代行せず、入力された証跡の整合性だけを判定します。
