# Google Play 公開準備状況（静的監査レポート）

対象ブランチ：`agent/issue146-device-qa`（master `51755ce` + PR #140統合済み）  
作成日：2026-07-29  
作成方法：静的監査（コミット・push・Secrets変更・Play Console操作・AABアップロード・審査提出は一切実施していない）

本ドキュメントはIssue #98（署名証明書照合）、#59（正式Release artifact）、#94（Play Console・内部テスト・審査提出）の**静的確認結果**です。実値・実操作の「設定済み/未設定」判定は行わず、確認すべき項目のチェックリストと、ユーザーが実施・承認すべき操作の順序を整理します。

---

## 1. 各Issueの現状とゲート位置

### 1.1 実行順序の定義（コード側のゲート実装）

`tool/release_execution_orchestrator.py` にゲート順序が実装されています。

- Issue順序：`Issue #60 → Issue #98 → Issue #59 → Issue #94`（`issueOrder: [60, 98, 59, 94]`）
- 機械判定ゲート：`releaseSession → issue60 → playSigning → formalRelease → playSubmission → internalTest`（`gateOrder`）
- 最終判定は全ゲートPASS時のみ `READY_FOR_SUBMISSION`、それ以外は `KEEP_BLOCKED`
- 次アクションは最初にBLOCKEDとなったゲートから機械的に導出（`next_action`）

**静的監査結果：ゲート順序は要件どおり実装済み**。`release-execution-gate.yml` CI がコード上の `issueOrder`/`gateOrder`/runbook 順序を契約テストで固定しており、PR #140統合後の最新masterでもこの契約は維持されています。

### 1.2 GitHub上のIssue状態（2026-07-29時点、gh APIで確認）

| Issue | タイトル | 状態 | ラベル | 最終更新 |
|---|---|---|---|---|
| #60 | Re-schedule active todo notifications after app startup | OPEN | kilo-duplicate, kilo-triaged | 2026-07-26 |
| #98 | [P1] 本番提出前にAndroid署名証明書をPlay Consoleと照合する | OPEN | kilo-duplicate, kilo-triaged | 2026-07-23 |
| #59 | [P1] Confirm GitHub Actions status for latest master before release | OPEN | kilo-duplicate, kilo-triaged | 2026-07-23 |
| #94 | [P1] Play Console設定・内部テスト・ストア提出を完了する | OPEN | なし | 2026-07-13 |

3 Issueとも **OPEN** です。

### 1.3 現在どこで止まっているか（ゲート位置）

| ゲート | 状態 | 根拠 |
|---|---|---|
| releaseSession | BLOCKED（未開始） | 実証跡 `release-session.json` はリポジトリに存在せず。Issue #60の実測が開始されるまで開始されない |
| issue60 | BLOCKED（実測未完了） | Issue #60コメント（2026-07-26）：「PR #133/#134マージ後の最新masterで実測を開始する予定」「emulator-5554へのアクセスがないためNormal/Reboot/install-rを実施済みとは扱わない」。実機のNormal/Reboot/install-r証跡が未取得 |
| playSigning | BLOCKED（外部未実施） | Issue #98：Play Consoleでのアプリ作成・Play App Signing・アップロード証明書SHA-256取得・課金商品作成が未実施 |
| formalRelease | BLOCKED（実行証跡なし） | Issue #59：正式 `workflow_dispatch`/`v*`タグRunの正式APK/AAB/evidence artifactと `release-manifest.json` が未取得 |
| playSubmission | BLOCKED（前提未達） | Issue #94：正式Release後に対応 |
| internalTest | BLOCKED（前提未達） | Issue #94：正式AABの内部テスト配布・Play経由実機確認が未実施 |

**結論：現在のクリティカルパスは Issue #60（releaseSession + issue60 ゲート）で止まっている**。`playSigning`（#98）以降は、#60の集約とRelease sessionのSource SHA確定後に開始できます。

### 1.4 直近のGitHub Actions実績（API照会）

- master最新 `51755ce`（#144）の push で `Flutter CI` / `Flutter Release Validation` / `Release Automation Validation` がすべて **success**。
- `release-android.yml`（Android Internal Release）は **2026-07-28に `v0.7.0` タグ push で実行され success**（run `30360560641`、HEAD `fa73fdb`）。ただしこれは内部テスト配布の実行であり、Issue #98/#59の完了条件である「`ANDROID_UPLOAD_CERT_SHA256` 照合つき正式Release」の証跡ではありません。
- Issue #98/#59コメント記載のrun `30021852905`（master `8f60384`）では `release-build` が「`IAP_AI_ACCESS_PRODUCT_ID` variable と `ANDROID_UPLOAD_CERT_SHA256` variable 未設定」で停止。→ **この2つのVariable（うち1つは必須）が以前から未設定のまま**であることが、GitHub APIの現状照会でも裏付けられました。

---

## 2. 必須Secrets / Variablesチェックリスト

### 2.1 必須Secrets（8件）

| # | Secret名 | 用途 | 参照箇所 | 監査メモ |
|---|---|---|---|---|
| 1 | `KEYSTORE_BASE64` | アップロードキーストア（Base64） | ci.yml release-build / release-android.yml / ANDROID_RELEASE.md | API上は名前が存在（値は非公開） |
| 2 | `KEYSTORE_STORE_PASSWORD` | キーストアパスワード | 同上 | 同上 |
| 3 | `KEYSTORE_KEY_PASSWORD` | 鍵パスワード | 同上 | 同上 |
| 4 | `KEYSTORE_KEY_ALIAS` | 鍵エイリアス | 同上 | 同上 |
| 5 | `ADMOB_APP_ID` | 本番AdMob App ID | ci.yml / release-android.yml | 同上 |
| 6 | `ADMOB_BANNER_AD_UNIT_ID` | 本番バナー広告ユニットID | ci.yml / release-android.yml | 同上 |
| 7 | `GEMINI_PROXY_URL` | AI解析用Cloudflare Workers URL | ci.yml / release-android.yml | 同上 |
| 8 | `PLAY_SERVICE_ACCOUNT_JSON` | Google Play APIサービスアカウントJSON | release-android.yml / PLAY_INTERNAL_RELEASE.md | 内部テスト配布で必須 |

### 2.2 必須Repository Variables（1件）

| # | Variable名 | 用途 | デフォルト | 監査メモ |
|---|---|---|---|---|
| 1 | `ANDROID_UPLOAD_CERT_SHA256` | Play Consoleアップロード証明書SHA-256（正式Releaseの照合必須） | なし（必須） | **API照会で未設定を確認**。ci.yml release-buildとrelease-android.ymlの照合に使われ、未設定ならビルド前に停止 |

### 2.3 任意Repository Variables（2件）

| # | Variable名 | 用途 | デフォルト |
|---|---|---|---|
| 1 | `IAP_REMOVE_ADS_PRODUCT_ID` | 広告削除商品ID | `remove_ads` |
| 2 | `IAP_AI_ACCESS_PRODUCT_ID` | AI分析商品ID | `ai_analysis` |

API照会ではこの2件は設定済みでしたが、**値（`remove_ads`/`ai_analysis`か上書き値か）は静的には判定しません**。Play Consoleで作成する課金商品IDと一致させる必要があります。

> 判定方針：本レポートは「設定済み/未設定」の最終判定をしません（APIではSecretsの値は照会不可、Variable値は本タスクの対象外）。設定作業はユーザーが各管理画面で行い、`docs/PLAY_CONSOLE_SUBMISSION.md` §3のチェックリストを順に埋めてください。

---

## 3. Play Consoleで人間が行う操作の順番付きチェックリスト

出典：`docs/PLAY_CONSOLE_SUBMISSION.md`、`docs/PLAY_INTERNAL_RELEASE.md`、`docs/RELEASE_EXECUTION_PLAN.md`、`docs/STORE_LISTING_JA.md`、`docs/store/google-play-data-safety.md`

### ステージ0：アカウント確認（#94コメント由来）

- [ ] デベロッパーアカウント種別が個人か組織かを確認（アカウント詳細）
- [ ] **個人アカウントの場合**：正式公開前に「最低12人が14日間連続オプトインするクローズドテスト」が必要（内部テストのみでは要件を満たさない）→ テスター募集の早期開始を判断

### ステージ1：playSigning（#98、正式Release前）

- [ ] アプリを新規作成（未作成の場合）
- [ ] Application ID = `com.ashita_motsumono`
- [ ] アプリ名 = 「あしたもつもの」
- [ ] デフォルト言語 = 日本語（ja / ja-JP）
- [ ] アプリの種類 = 無料アプリ
- [ ] Play App Signing を設定
- [ ] **アップロード証明書SHA-256を取得**（アプリ署名画面）
- [ ] 本番アップロードキーストアのSHA-256と一致することを確認（`keytool -list -v`。`CN=Test`等のCI鍵を本番鍵と推測しない）
- [ ] 課金商品を2件作成（非消費型）
  - [ ] 広告削除：ID = `IAP_REMOVE_ADS_PRODUCT_ID`（未設定時 `remove_ads`）
  - [ ] AI分析：ID = `IAP_AI_ACCESS_PRODUCT_ID`（未設定時 `ai_analysis`）
- [ ] ライセンステストアカウント（テスト購入用）を追加（設定 > ライセンステスト）

### ステージ2：GitHub登録（ユーザー操作）

- [ ] Secrets 8件の値を登録/確認（§2.1）
- [ ] Variable `ANDROID_UPLOAD_CERT_SHA256` にPlay ConsoleのSHA-256を登録（**現状未設定**）
- [ ] Variable 2件の値がPlay Consoleの商品IDと一致することを確認
- [ ] `google-play-internal` Environment（必要ならrequired reviewers）を確認
- [ ] `play-console-evidence.json` の署名準備項目を確認済み事実だけで更新

### ステージ3：formalRelease（#59）

- [ ] Issue #60集約と `playSigning` がPASSしている
- [ ] Release sessionのSource SHAが最新clean `origin/master` と一致
- [ ] `Release Android`（ci.yml の release-build）を `workflow_dispatch` または正式 `v*` タグで実行
- [ ] artifact 3種を確認：`ashita-motsumono-signed-release-apk` / `ashita-motsumono-signed-release-aab` / `ashita-motsumono-release-evidence`
- [ ] `release-manifest.json` を取得し `Documents\ashita-release-evidence` へ保存
- [ ] キーストア・APK・AABの3証明書照合がすべて `matches: true`
- [ ] APK/AAB SHA-256が実ファイルと一致
- [ ] manifestのcommit SHAがRelease sessionと一致
- [ ] orchestratorの `formalRelease` がPASS

### ステージ4：playSubmission（#94、正式Release後）

- [ ] プライバシーポリシーURL登録（公開予定 `https://lp-5t7.pages.dev/apps/ashita-motsumono/privacy`）
- [ ] サポート/連絡先URL登録（`https://lp-5t7.pages.dev/apps/ashita-motsumono/contact`）が実際に受信・返信可能
- [ ] 短い説明（80文字以内）を `docs/STORE_LISTING_JA.md` から転記
- [ ] 詳細説明を転記
- [ ] アイコン `assets/store/icon-512.png` を登録
- [ ] スクリーンショット5枚を登録（`assets/store/screenshots/01-home.png` 〜 `05-settings-supporter.png`）
- [ ] カテゴリ = 「ツール」
- [ ] 連絡先メールアドレス登録
- [ ] データセーフティ完了（回答草案 `docs/store/google-play-data-safety.md`、チェックリスト `docs/store/store-disclosure-consistency-checklist.md`）
- [ ] コンテンツレーティング完了
- [ ] 広告申告完了（AdMob / UMP / 同意フロー）
- [ ] 審査説明完了（カメラ、通知、課金、AI画像解析の外部送信）
- [ ] `play-console-evidence.json` の提出項目を確認済み事実だけで更新
- [ ] orchestratorの `playSubmission` がPASS

### ステージ5：internalTest（#94）

- [ ] テストとリリース > テスト > 内部テスト を開く
- [ ] テスターのメールリストを作成（最大100人）
- [ ] オプトインURLをテスターへ共有
- [ ] 正式AABを内部テストトラックへアップロード（release-android.yml の `Android Internal Release`）
- [ ] テスター端末でPlay経由インストール
- [ ] 実機確認項目（`internal-test-evidence.json` の各項目）：
  - [ ] カメラ撮影 / 画像選択 / 日本語OCR / 候補確認・編集・登録
  - [ ] OCR・AI失敗時の手入力フォールバック
  - [ ] 通知表示 / 通知拒否時もTodo登録可能
  - [ ] 本番AdMob広告表示 / 広告失敗時も主要機能利用可能
  - [ ] 広告削除：価格表示、購入、広告非表示、購入復元
  - [ ] AI分析：価格表示、同意、購入、実行、購入復元
  - [ ] 全データ削除 / JSONエクスポート
- [ ] `internal-test-evidence.json` を確認済み事実だけで更新
- [ ] orchestratorの `internalTest` がPASS

### ステージ6：最終提出（#94）

- [ ] `release-readiness.json` が `READY_FOR_SUBMISSION`
- [ ] Play Consoleに必須未入力・blocking warningがない
- [ ] 審査提出
- [ ] 公開Google Play URL取得
- [ ] LPへGoogle Play URL反映
- [ ] Issue #94 Close

---

## 4. ロールバック手順

出典：`docs/PLAY_INTERNAL_RELEASE.md`（ロールバック節）、`docs/ANDROID_RELEASE.md`、`docs/RELEASE_EXECUTION_PLAN.md`

### 4.1 一般原則

- **Google Playでは使用済みversionCodeを再利用できない**。
- 問題が出た場合は「当該リリースの停止」→「修正版を**より大きいversionCode**で再アップロード」が基本形。
- 内部テストリリースはPlay Consoleの「テストとリリース > テスト > 内部テスト」でリリースを停止（draft化・削除）できる。
- 正式AABは `release-manifest.json`（commit SHA、version、Run ID、証明書、APK/AABハッシュ）と `Documents\ashita-release-evidence` の証跡で追跡する。

### 4.2 段階別ロールバック

| 段階 | 操作 |
|---|---|
| AABをアップロードしたが配布前 | リリースを削除・draft化して再アップロード（versionCodeを上げる） |
| 内部テストで配布済み・問題発見 | 内部テストリリースを停止 → 修正版を大きいversionCodeで再アップロード → 再テスト |
| 審査提出前 | Play Consoleで提出を取り下げ、`release-readiness.json` を再評価 |
| 審査提出後・公開前 | リリースを保留（hold）または取り下げ。公開済みの場合はアップデートで差し替え |
| 公開後（Production） | 新versionCodeの修正版をProductionへ段階公開。公開済みversionCodeの取り下げはPlay Consoleのポリシーに従う |

### 4.3 鍵・資格情報の漏えい時

- 署名鍵（upload keystore）やサービスアカウント鍵が漏えいした場合は**直ちに無効化・削除**し、GitHub Secretsを更新する。
- Play App Signing導入後は、アップロード鍵の紛失・漏えい時にPlay Consoleからアップロード鍵をリセットできる場合があるが、手順はPlay Consoleの案内に従う。

### 4.4 作業レベル（GitHub/ローカル）の巻き戻し

- Release session開始後、Issue #60集約まではmasterへの別PRマージを凍結（`mergeFreezeRequiredUntilIssue60Aggregation`）。
- 証跡ルートは `Documents\ashita-release-evidence` に統一。以前の証跡がある場合は `tool/release_validation_control.ps1 -Action ArchiveSession` で非破壊退避（`ashita-release-evidence-archive-YYYYMMDD-HHMMSS`、`archive-manifest.json` 生成）。元の証跡は削除しない。
- 進行中sessionの退避は誤操作防止のため拒否され、`-ForceArchiveActive` は通常運用では使用しない。
- 古いSource SHAで取得した通知証跡は、新しいmasterのClose証跡として流用しない。

---

## 5. 証跡テンプレートの整合確認（静的監査）

### 5.1 `tool/release_validation_session.ps1`（単一セッションドライバ）

- 証跡ルート `Documents\ashita-release-evidence` に以下を生成：`release-session.json`、`play-console-evidence.json`、`release-manifest.json`、`internal-test-evidence.json`、`release-readiness.json`、`release-readiness.md`、`release-validation-state.json`
- `WriteTemplates` アクションが orchestrator の `write-template --kind play-console|internal-test` を呼び、テンプレートを生成
- プレースホルダーはすべて False/空で、確認済み事実だけを人が True に更新する前提

### 5.2 `tool/release_execution_gate.py` / `tool/release_execution_orchestrator.py` のテンプレート

- **play-console テンプレート**：`applicationId`（固定 `com.ashita_motsumono`）、`appName`（固定 `あしたもつもの`）、`defaultLanguage`（ja/ja-JP）、署名項目 `appCreated`/`playAppSigningEnabled`/`iapProductCreated`/`iapAiProductCreated`、提出項目 `privacyPolicyRegistered`/`storeListingComplete`/`dataSafetyComplete`/`contentRatingComplete`/`adsDeclarationComplete`、`uploadCertificateSha256`、`iapProductId`（既定 `remove_ads`）、`iapAiProductId`（既定 `ai_analysis`）
- **internal-test テンプレート**：`sourceSha`、`releaseRunId`、`testedAtUtc`、`tester`、`notes` + 13個の必須True項目（`aabUploaded`〜`jsonExportPassed`）
- orchestratorは `issueOrder [60,98,59,94]` / `gateOrder` を固定し、次アクションを機械的に決定

### 5.3 整合確認の結果

- ワークフローが要求するSecrets/Variables名（§2）と、テンプレート・ドキュメントの名前は一致。
- `release-manifest.json`（`tool/generate_release_manifest.py`）が記録する項目：commit SHA、ref、version、Application ID、アップロード証明書SHA-256、3照合（uploadKeystore/APK/AAB）、APK/AAB SHA-256、課金商品ID 2件、artifact名、Run ID/Attempt。Secrets・パスワード・AdMob ID・Gemini URLは記録しない。
- 最終判定は `README_FOR_SUBMISSION` ではなく `READY_FOR_SUBMISSION`（コード・文書とも表記一致）。

---

## 6. ユーザーが実施または承認すべき操作（順番付き）

> 各操作は、本レポート作成時点で**未実施**です（静的監査のみのため）。実施前に、各ステップの前提ゲートがPASSしていることを確認してください。

### Step 0（Issue #60の完了 — 現在の停止位置）

1. **承認**: PR #133 / #134 をmasterへマージし、最新clean `origin/master` を確定する（Issue #60コメント 2026-07-26 の手順）。
2. **実施（要PC・エミュレータ）**: `git worktree add` で専用worktreeを作成し、`tool/release_validation_session.ps1` から `Doctor` → `BuildInstall` → `StartSession` → Normal → Reboot → install-r → `Aggregate` を実施（`emulator-5554`、通知権限GRANTED、+09:00、Todo作成・通知目視が必要）。
3. **実施**: `issue60-summary.json/md` をIssue #60へ記録。`release-readiness` を途中評価。
4. **承認**: Issue #60のCloseレビュー（Normal PASS / Reboot PASS / install-r PASSまたは限定的INCONCLUSIVE、同一Source SHA、最新clean origin/master）。

### Step 1（#98 playSigning — 要Play Consoleアカウント）

5. **実施**: Play Consoleでアプリ作成（Application ID `com.ashita_motsumono`、名称「あしたもつもの」、日本語、無料）。
6. **実施**: Play App Signing設定、アップロード証明書SHA-256を取得。
7. **実施**: 本番upload keystoreのSHA-256と一致確認（`keytool -list -v`）。
8. **実施**: 課金商品2件作成（`remove_ads` / `ai_analysis` またはVariableの上書き値）。
9. **承認**: `ANDROID_UPLOAD_CERT_SHA256` Variable登録（**現状未設定**）。
10. **承認**: Secrets 8件（§2.1）の値の登録・確認。
11. **実施**: `play-console-evidence.json` 更新 → orchestratorの `playSigning` PASSを確認。
12. **承認**: Issue #98 Close判断。

### Step 2（#59 formalRelease — 要GitHub Actions）

13. **実施**: `Release Android`（workflow_dispatch）または正式 `v*` タグを実行（Release sessionのSource SHAと一致するmasterから）。
14. **実施**: artifact 3種と `release-manifest.json` を `Documents\ashita-release-evidence` へ保存。
15. **実施**: 3証明書 `matches: true`、APK/AABハッシュ一致、commit SHA一致を確認。
16. **実施**: orchestratorの `formalRelease` PASSを確認し、結果をIssue #98/#59へ記録。
17. **承認**: Issue #59 Close判断。

### Step 3（#94 playSubmission）

18. **実施**: プライバシーポリシーURL・サポートURLを公開し、Play Consoleへ登録。
19. **実施**: ストア掲載（説明・アイコン・スクリーンショット5枚・カテゴリ・連絡先）を `docs/STORE_LISTING_JA.md` から転記。
20. **実施**: データセーフティ・コンテンツレーティング・広告申告・審査説明（`docs/store/google-play-data-safety.md`、`store-disclosure-consistency-checklist.md` 参照）。
21. **実施**: `play-console-evidence.json` 更新 → `playSubmission` PASS確認。

### Step 4（#94 internalTest）

22. **承認**: Google Cloud / Play Consoleでサービスアカウント作成・権限付与（「アプリ情報の表示」+「テストトラックへのリリース」最小権限）→ `PLAY_SERVICE_ACCOUNT_JSON` 登録。
23. **実施**: 内部テストのテスターリスト作成・オプトインURL共有。
24. **実施**: `Android Internal Release`（release-android.yml）でAABを内部テストトラックへアップロード。
25. **実施**: Play経由インストール + 実機スモークテスト（OCR/通知/広告/課金/AI/削除/エクスポート）。
26. **実施**: `internal-test-evidence.json` 更新 → `internalTest` PASS確認。

### Step 5（最終提出）

27. **実施**: `release-readiness.json` が `READY_FOR_SUBMISSION` であることを確認（orchestrator evaluate）。
28. **承認**: 審査提出。
29. **実施**: 公開Google Play URL取得 → LP反映 → Issue #94 Close。

> 個人アカウントの場合は Step 4 より前に「クローズドテスト（12人・14日）」の要件を満たす必要があります（§3 ステージ0 参照）。

---

## 7. 禁止事項（今回の監査で実施していないこと）

本レポート作成にあたり、以下は実施していません。

- 本番鍵の作成、キーストア変更
- GitHub Secrets / Variables の登録・変更
- Play Consoleでのアプリ作成・課金商品作成
- AABアップロード・内部テスト配布・審査提出
- Release作成・Production公開
- コミット・push・ブランチ変更

## 8. 参考ファイル

- `tool/release_execution_orchestrator.py` / `tool/release_execution_gate.py`（ゲート順序・証跡テンプレート）
- `tool/release_validation_session.ps1` / `tool/release_validation_control.ps1`（セッション・証跡ドライバ）
- `.github/workflows/ci.yml`（release-build）、`.github/workflows/release-android.yml`、`.github/workflows/release-validation.yml`、`.github/workflows/release-execution-gate.yml`
- `docs/RELEASE_EXECUTION_PLAN.md` / `docs/ANDROID_RELEASE.md` / `docs/PLAY_CONSOLE_SUBMISSION.md` / `docs/PLAY_INTERNAL_RELEASE.md` / `docs/STORE_LISTING_JA.md`
- `docs/store/google-play-data-safety.md` / `docs/store/store-disclosure-consistency-checklist.md` / `docs/privacy_policy.md`
