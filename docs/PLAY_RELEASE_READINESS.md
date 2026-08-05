# Google Play公開準備状況

基準日：2026-08-05  
対象master：`e5fe676443319f55b2be5302aae322d1b5c6677e`  
アプリバージョン：`0.7.0+3`

## 結論

判定は`KEEP_BLOCKED_EXTERNAL_RELEASE_GATES`です。

コード品質ゲートと署名済みAPK/AABを生成・検証する仕組みは整っていますが、通知実測、Play App Signing、本番アップロード証明書、正式Release、Play Console入力、内部テストの外部証跡が揃っていません。CI成功やPR用の一時署名成果物を、正式なPlay提出証跡の代替にしません。

## 最新のコード・CI状態

統合PR #158で次が成功しています。

- Release Automation Validation `30974846475`: SUCCESS
- Flutter CI `30974846504`: SUCCESS
- Flutter Release Validation `30974846503`: SUCCESS
  - Dart format
  - Analyze
  - 全Flutter test
  - release APK build
  - release AAB build
  - artifact verification/upload

PR #158はmasterへsquash merge済みです。

- master commit：`e5fe676443319f55b2be5302aae322d1b5c6677e`
- merge後`flutter-ci-master`：SUCCESS
- run：`30978701905`

正式Release jobは、Analyzeと全testの成功後、かつ最新masterだけから実行できるよう制限されています。

## リリースゲート

実行順は次のとおりです。

```text
releaseSession
→ issue60
→ playSigning
→ formalRelease
→ playSubmission
→ internalTest
```

| Issue | ゲート | 状態 | 残作業 |
|---:|---|---|---|
| #60 | `issue60` | BLOCKED | Normal／Reboot／install-r通知実測、同一Source SHAで集約 |
| #98 | `playSigning` | BLOCKED | Play App Signing、本番upload証明書SHA-256、商品ID、証跡 |
| #59 | `formalRelease` | BLOCKED | 正式workflow/tag run、manifest、証明書・hash照合 |
| #94 | `playSubmission` | BLOCKED | ストア掲載、データセーフティ、広告申告、審査情報 |
| #94 | `internalTest` | BLOCKED | Play経由インストール、OCR・通知・広告・課金・AI・復元等 |

## GitHub設定の事実

この文書はSecret／Variableの値を読み取り・変更していません。以下はworkflowが要求する名前と条件です。

### 正式Release：`.github/workflows/ci.yml`

必須Secrets：

- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`
- `GEMINI_PROXY_URL`

必須Repository Variables：

- `IAP_REMOVE_ADS_PRODUCT_ID`
- `IAP_AI_ACCESS_PRODUCT_ID`
- `ANDROID_UPLOAD_CERT_SHA256`

正式Releaseでは、キーストア、APK、AABの証明書を`ANDROID_UPLOAD_CERT_SHA256`と照合します。未設定または不一致の場合、正式成果物として完了しません。

### 内部テスト配布：`.github/workflows/release-android.yml`

上記の署名・AdMob・Gemini設定に加えて、次が必須です。

- `PLAY_SERVICE_ACCOUNT_JSON`
- `IAP_REMOVE_ADS_PRODUCT_ID`
- `IAP_AI_ACCESS_PRODUCT_ID`

`ANDROID_UPLOAD_CERT_SHA256`はこのworkflowでは条件付きです。値がある場合だけ証明書照合を実行します。値なしで内部テストworkflowが進行できても、Issue #98の`playSigning`やIssue #59の`formalRelease`をPASSしたことにはなりません。

## 正式Release成果物

正式Releaseが成功した場合、次を同じSource SHA・Run IDで管理します。

- `ashita-motsumono-signed-release-apk`
- `ashita-motsumono-signed-release-aab`
- `ashita-motsumono-release-evidence`
- `release-manifest.json`

`release-manifest.json`で確認するもの：

- commit SHA／ref／Run ID
- Application ID／version
- upload keystore、APK、AABの証明書
- APK／AAB SHA-256
- 課金商品ID
- artifact名

秘密鍵、パスワード、AdMob ID、Gemini URLは証跡へ保存しません。

## 外部環境で必要な作業

1. Issue #60の通知実測を完了
2. Play ConsoleでアプリとPlay App Signingを設定
3. 本番upload keystoreとPlay ConsoleのSHA-256を一致確認
4. 課金商品IDを作成しRepository Variablesと一致確認
5. 正式masterからRelease workflowまたは正式タグを実行
6. manifest、証明書、APK/AAB hashを検証
7. Play Consoleのストア掲載・データセーフティ等を完了
8. 正式AABを内部テストへ配布
9. Play経由端末でOCR、通知、広告、課金、AI、購入復元、削除、exportを確認
10. orchestratorが`READY_FOR_SUBMISSION`を返した後だけ審査提出

## 今回実施していない操作

- Secret／Variableの値変更
- 本番鍵の作成・取得
- タグ／Release作成
- Play Console入力
- AABアップロード
- 内部テスト配布
- Worker本番デプロイ
- 審査提出／Production公開

## 最終判定ルール

- コード・CI：`PASS_AUTOMATED`
- 外部証跡：`KEEP_BLOCKED_EXTERNAL_RELEASE_GATES`
- 全ゲート通過時のみ：`READY_FOR_SUBMISSION`
