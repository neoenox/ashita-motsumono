# Google Play公開準備状況

基準日：2026-08-16
対象master：`b010a9d646182e9591b269d8731b60f02ffb860b`
アプリバージョン：`0.7.0+3`

## 結論

判定は`KEEP_BLOCKED_EXTERNAL_RELEASE_GATES`です。

コード品質ゲートと署名済みAPK/AABを生成・検証する仕組みは整っています。現行masterのworkflow_dispatchでも署名済みAPK/AAB、証明書照合、release manifest、artifact uploadが成功しています。クローズドテスト(Alpha)ではv0.7.0が公開中です。一方、通知実測、Play ConsoleのPlay App Signing確認、本番Play Console入力、本番内部テストの外部証跡は揃っていません。さらに、現行masterからのPlay再配布（`Android Internal Release`）はkeystore証明書フィンガープリント不一致で失敗しており、署名鍵の整合性確認が新たなブロッカーです。CIの自動証跡をPlay配布・実機受入の代替にしません。

## 最新のコード・CI状態

現行master `b010a9d646182e9591b269d8731b60f02ffb860b`（2026-08-14、#170 merge 後）で次が成功しています。

- Release Automation Validation `31771720995`: SUCCESS
- Flutter Release Validation `31771721000`: SUCCESS
- Flutter CI `31771720982`: SUCCESS
  - Dart format
  - Analyze
  - 全Flutter test
  - 署名済みrelease APK/AAB build
  - APK/AAB/キーストア証明書照合
  - release manifest生成
  - artifact upload

`31771721000`のrelease manifestは現行master SHAと一致し、APK/AAB/キーストア証明書の照合結果はすべて`matches=true`です。これは自動artifactの確認であり、Play Consoleでの証明書登録・内部テスト配布の確認ではありません。

## クローズドテスト(Alpha) 公開状況

- v0.7.0（`0.7.0+3`）がクローズドテスト(Alpha)トラックで公開中（2026-08-10 1:49 公開、審査完了）
- アップロードは run `30360560641`（2026-07-28、`fa73fdb416`）の成果物
- テスター: Google Group `aimitsumori-testers`（1名登録済み、2026-08-14 確認）
- 本番公開にはクローズドテスト14日間継続・テスター12人達成が要件（TODO.md）
- これは本番提出の受入証跡ではありません

## 署名鍵の整合性ブロッカー（2026-08-16 発見）

`Android Internal Release` workflow が master 履歴上のコミット `5ad77e62a3` / `9f73ee23c3` で失敗しています（run `31587962315` / `31591654675`、2026-08-12）。

- 失敗ステップ: `Verify *** keystore certificate`
- 期待値: `ANDROID_UPLOAD_CERT_SHA256` = `DF:5B:D8:9F:29:C4:4B:EC:FA:C1:48:3A:00:29:52:16:80:19:89:72:BA:A4:C0:7F:4F:4F:81:AD:EF:D6:91:E6`
- 実測: `8D:BE:CD:58:FA:97:6D:3C:22:3C:38:A5:1C:0D:FB:80:6D:7E:AC:10:E3:22:DF:D8:92:2D:B4:8C:2C:B6:30:E8`

現在のキーストアと登録済みアップロード証明書のどちらが正か確認できるまで、Play再配布・`formalRelease`・本番提出は進められません。Secrets／Variablesの値変更は外部環境の人間操作です。

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
| #60 | `issue60` | BLOCKED | Normal／Reboot／install-r通知実測をcurrent masterで再実行し、同一Source SHAで集約 |
| #98 | `playSigning` | BLOCKED | CI上の証明書照合は完了。Play ConsoleのPlay App Signing、upload証明書、商品IDの外部証跡が未確認。keystore不一致の調査が先行 |
| #59 | `formalRelease` | PASS_AUTOMATED_ARTIFACT | run `31771721000`で署名APK/AAB、manifest、証明書・hash照合を確認。ordered orchestrator gateはPlay signing証跡不足でBLOCKED。tag/Release公開やPlay uploadは未実施 |
| #94 | `playSubmission` | BLOCKED | クローズドテスト(Alpha)はv0.7.0公開済み（2026-08-10）。本番ストア掲載、データセーフティ、広告申告、審査情報は未完了 |
| #94 | `internalTest` | BLOCKED | 旧版v0.6.3+2は配布実績あり。現行masterからの再配布はkeystore不一致で不能。Play経由インストール、OCR・通知・広告・課金・AI・復元等を本番版で確認 |

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

正式Releaseでは、キーストア、APK、AABの証明書を`ANDROID_UPLOAD_CERT_SHA256`と照合します。未設定または不一致の場合、正式成果物として完了しません。2026-08-12の`Android Internal Release`失敗はこの照合の不一致を示しています。

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

1. **keystore証明書の整合性確認**（`ANDROID_UPLOAD_CERT_SHA256`と現行キーストアの不一致解消。`KEYSTORE_BASE64`またはVariableのどちらが正か確認）
2. Issue #60の通知実測をcurrent masterで完了
3. Play ConsoleでアプリとPlay App Signingを設定
4. 本番upload keystoreとPlay ConsoleのSHA-256を一致確認
5. 課金商品IDを作成しRepository Variablesと一致確認
6. 正式masterからの署名artifactを運用対象として確定
7. manifest、証明書、APK/AAB hashを検証（run `31771721000`で自動確認済み）
8. Play ConsoleのPlay App Signing、ストア掲載、データセーフティ等を完了
9. 正式AABを内部テストへ配布
10. Play経由端末でOCR、通知、広告、課金、AI、購入復元、削除、exportを確認
11. orchestratorが`READY_FOR_SUBMISSION`を返した後だけ審査提出

## 今回実施していない操作

- Secret／Variableの値変更（keystore不一致の修正を含む）
- 本番鍵の作成・取得
- タグ／Release作成
- Play Console入力
- AABアップロード
- 内部テスト再配布
- Worker本番デプロイ
- 審査提出／Production公開

## 最終判定ルール

- コード・CI：`PASS_AUTOMATED`
- 外部証跡：`KEEP_BLOCKED_EXTERNAL_RELEASE_GATES`
- 全ゲート通過時のみ：`READY_FOR_SUBMISSION`
