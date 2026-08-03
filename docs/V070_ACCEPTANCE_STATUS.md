# v0.7.0 受入状況（Issue #136 チェックリスト同期）

対象リポジトリ: `kaenozu/ashita-motsumono`
対象ブランチ: `agent/issue136-sync`（ベース master `51755ce`）
判定基準日: 2026年7月27日（master 最新 `51755ce`）
アプリバージョン: `0.7.0+3`（`pubspec.yaml`）

本ドキュメントは Issue #136「v0.7.0: PDF/複数画像取り込みと確認画面UX改善」のチェックリストを、
コード・テスト・docs・実機証跡で確認できた事実のみで判定し、Issue本文のチェックを機械的に変更したものではありません。

## 判定区分

- **実装済み**: コードと自動テストで確認できた（実機証跡の有無を併記）
- **一部実装**: 中核機能はあるが、チェック項目の一部（UI・並び替え等）が未対応
- **未実装**: 対応するコード・テスト・UIが見つからない
- **検証待ち**: 実装・自動検証は済んでいるが、実機/外部ゲートでの確認が未実施

## サマリー

| セクション | 実装済み | 一部実装 | 未実装 | 検証待ち |
|---|--:|--:|--:|--:|
| 入力経路の強化（5項目） | 3 | 2 | 0 | 0 |
| 確認画面の修正コスト削減（6項目） | 2 | 0 | 4 | 0 |
| 検証（6項目） | 0 | 0 | 2 | 4 |
| 合計 | 5 | 2 | 6 | 4 |

---

## 1. 入力経路の強化

### 1-1. PDF取り込み（学校アプリ・メールからの共有、複数ページ選択） — **実装済み**

根拠:
- `lib/src/services/pdf_pick_service.dart`（`file_picker` で端末からPDF選択）
- `lib/src/services/pdf_render_service.dart`（PDFヘッダ検証、暗号化/破損/サイズ/ページ数制限、全ページをJPEGへ逐次レンダリング、`maxPages=20`）
- `lib/src/services/document_intake_service.dart` の `importPdf()`（Stagingコピー → SHA-256フィンガープリント → ページ単位レンダリング → ページ単位OCR → ページ保存）
- 共有経路: `lib/src/services/receive_share_handler_sources.dart` の `_processPdf()`、`android/app/src/main/AndroidManifest.xml` に `SEND application/pdf` と `VIEW application/pdf`（content scheme）のintent-filter
- 複数ページ: `DbDocumentPage`（`lib/src/repositories/app_database.dart`）に全ページを保存し、`DocumentIntakeService.importPdf()` は全ページをOCR・保存
- テスト: `test/pdf_pick_service_test.dart`、`test/document_intake_service_test.dart`（複数ページOCR/進捗/重複/ロールバック）、`test/receive_share_handler_test.dart`（PDFルーティング、ACTION_VIEW相当のcontent URI）

補足: 「複数ページ選択」はPDF内の全ページを取り込む方式で、チェック項目1-2の「ページ順変更・除外」UIとは別物。後者（1-2）は未実装。

### 1-2. 複数画像の一括取り込み（表面・裏面・複数枚、ページ順変更・除外） — **一部実装**

根拠（実装済み部分）:
- 複数枚一括: `OcrPickService.pickMultipleImages()`（`lib/src/services/ocr_pick_service.dart`）が `ImagePicker.pickMultiImage` で複数選択し、`DocumentIntakeService.importImages()` が全枚をOCR・ページ保存
- 表面・裏面・複数枚: Android共有の `ACTION_SEND_MULTIPLE image/*`（Manifest）→ `ReceiveShareHandler._processMultipleImages()` が全画像を `importImages` へ一括投入（`test/receive_share_handler_test.dart` の「routes all shared images to one importImages call in order」）
- ページ順は選択順を `pageIndex` として保持（`importImages()` の `sourcePaths` 順）

未実装部分:
- ページ順変更（ドラッグ等で並び替え）のUI
- 不要ページの除外UI（取り込み前の選択画面がなく、撮影後の `ReviewExtractionsScreen` の選択解除のみ）
- 上記UI/モデル操作はコード上に見当たらない（`lib/src/screens/`、`lib/src/models/` を確認）

### 1-3. Android共有経路の改善（LINE, Google Drive, メール, 写真アプリ） — **実装済み**

根拠:
- `lib/src/services/receive_share_handler.dart` / `_runtime.dart` / `_sources.dart` / `_state.dart`
  - アプリ起動中: `getMediaStream()` 購読、逐次キュー処理、短期重複（2秒以内の同一payload）抑止
  - 未起動時: `getInitialMedia()` で初回共有を処理
  - テキスト・単一画像・複数画像・PDFを分類し、画像+PDF混合・複数PDFを明示拒否
- `lib/src/services/share_file_staging_service.dart` + `android/app/src/main/kotlin/com/ashita_motsumono/MainActivity.kt`
  - content:// URI をネイティブでアプリキャッシュ領域へコピー（`copyContentUriToStaging`、サイズ上限5MB画像/25MB PDF、キャッシュ外宛先拒否、失敗時ファイル削除）
  - 受け取った一時パスも自前Stagingへ再隔離し、`finally` でStagingごと削除
- Manifest intent-filter: `SEND text/plain`、`SEND image/*`、`SEND_MULTIPLE image/*`、`SEND application/pdf`、`VIEW application/pdf`
- テスト: `test/receive_share_handler_test.dart`（複数画像一括、単一画像既存フロー維持、混合拒否、PDFルーティング、Staging後始末、Manifest/MainActivity契約）

補足: LINE/Google Drive/メール/写真アプリそれぞれの実機共有は未実施（実機証跡なし）。コード上の経路（ACTION_SEND系）は網羅されており実装は完了。

### 1-4. 同一ファイルの二重登録防止 — **実装済み**

根拠:
- PDF: `DocumentIntakeService.importPdf()` がSHA-256（`sourceFingerprint`）を計算し、レンダリング前と保存前の2回 `_findDocumentByFingerprint()` で重複判定 → `IntakeDuplicate`（`test/document_intake_service_test.dart`「returns duplicate before rendering an imported PDF」、`app_database.dart` の `idx_db_document_source_fingerprint` 索引）
- 画像: OCRテキストの `TextFingerprint`（`lib/src/utils/text_fingerprint.dart`）によるセッション内重複判定＋TTL1時間の `_completedFingerprints`（`receive_share_handler_state.dart`）。`OcrPickService` 側はDB永続フィンガープリントなし
- テキスト: `TextFingerprint` による重複判定（`_processText()`）
- UI: `_showDuplicateDialog`（「このPDF/画像は取り込み済みです」）

補足: 画像は「同一バイナリ」のSHA-256ではなくOCRテキスト指紋による重複判定（同一内容の別画像も重複扱い）。PDFはバイナリSHA-256。ギャラリー選択（`OcrPickService`）経由の画像には永続的なフィンガープリント重複判定が無いため、厳密には「同一ファイルの二重登録防止」は共有経路で完全、アプリ内画像選択経路は部分的な実装。

### 1-5. アプリ起動中・未起動の双方で一貫した共有動作 — **実装済み**

根拠:
- `ReceiveShareHandler.start()`（`receive_share_handler_runtime.dart`）が `getMediaStream()`（起動中）と `getInitialMedia()`（未起動起動時）の両方を同一キュー `_enqueue` → `_processIncoming` で処理し、両者に同じ分類・重複・Staging・結果フローを適用
- `_resetSafely()` で受信後リセット
- テスト: `test/receive_share_handler_test.dart` は `process()` を直接検証（起動中/未起動の両経路が同一 `process()` に合流する構造）。エミュレータ/実機での共有実測証跡はなし

---

## 2. 確認画面の修正コスト削減

### 2-1. 元文の該当箇所とTodo候補を対応表示 — **未実装**

根拠: `lib/src/screens/review_extractions_screen.dart` は候補カード（タイトル・種類・日付・金額・持ち物）の一覧のみで、元文（OCR全文）の該当箇所をハイライト/対応表示するUI・ロジックが見当たらない。`ExtractionDraft.rawText` は編集時の引き継ぎ（`review_extraction_screen.dart:307`）と手入力のメモ欄にのみ使用され、対応表示には使われていない。

### 2-2. 日付・持ち物・提出物・集金を候補ごとに編集 — **実装済み**

根拠:
- `ReviewExtractionScreen`（`lib/src/screens/review_extraction_screen.dart`）でタイトル・種類（TodoCategory: 持ち物/提出物/集金等）・期限（日付ピッカー＋クリア）・持ち物・金額・通知設定・メモを候補ごとに編集可能
- 複数候補は `ReviewExtractionsScreen._editDraft()` → `ReviewExtractionScreen(editOnly: true)` で個別編集し、`BulkExtractionReviewState.updateDraft()` で一覧へ反映
- テスト: `test/bulk_extraction_review_state_test.dart`（編集が登録対象へ反映、選択・クリア）

### 2-3. 同じ誤認識を一括修正 — **未実装**

根拠: 「同じ誤認識（例: 複数候補に現れる同一誤字/誤分類）を一括で修正」する機能は、コード・モデル・UIのいずれにも見当たらない（`bulk_extraction_review_state.dart` は候補単位の `updateDraft`/`setSelected` のみ。一括置換・全候補適用のAPIなし）。

### 2-4. 不要候補の複数選択削除 — **実装済み**

根拠:
- `BulkExtractionReviewState`（`lib/src/models/bulk_extraction_review_state.dart`）の `setSelected(index, bool)` で複数候補を個別に選択解除でき、`selectedDrafts` は選択済みのみを返す
- `ReviewExtractionsScreen` はチェックボックス（初期値: 全選択）＋「N件を登録」で、選択外の候補を登録対象から除外
- テスト: `test/bulk_extraction_review_state_test.dart`「registration payload contains only selected edited drafts」

### 2-5. 抽出できなかった場合に手入力へ即座に移行 — **実装済み**

根拠:
- `lib/src/screens/no_candidates_screen.dart`: 候補ゼロ時にOCR全文表示＋全文編集からの再抽出＋手入力フォームを同一画面で提供
- 導線: `add_todo_screen_actions.dart`（`_pickImages` は `showNoCandidates: true`）、`home_screen_actions.dart`（共有PDF/画像の候補ゼロ → NoCandidatesScreen）
- テスト: 画面の直接テストは無いが、`document_intake_service_test.dart` の `IntakeNoCandidates`（OCR全文・ページ付き保存）と `ocr_pick_service_intake_result_test.dart` で経路は検証

### 2-6. ユーザー修正の辞書反映（実装済み）の取り消しUI — **未実装**

根拠:
- 辞書反映（実装済み）: 登録・編集時に `AppSettings.addLearnedItemLabels()` で持ち物ラベルを学習（`review_extractions_screen.dart:196`、`review_extraction_screen.dart:327`、`no_candidates_screen.dart:342`）
- 取り消しUI: `AppSettings.clearLearnedItemLabels()` は存在するが、**「登録データをすべて削除」時のみ**呼ばれる（`settings_screen.dart:316`）。学習ラベル単体の一覧表示・個別/一括取り消しUIは存在しない（`settings_screen.dart` に該当セクションなし）

---

## 3. 検証

### 3-1. 実際のプリント・スクリーンショット・PDFを30件以上検証 — **未実施（検証待ち）**

根拠: リポジトリ内（`docs/`、`docs/validation/`、`integration_test/`、`test/fixtures/`）に30件以上の実物素材検証の記録・証跡が見当たらない。実機テスト手順（`docs/testing/release-device-test-plan.md` DEV-020〜DEV-023）は存在するが、実施結果の記録（`release-test-results-template.md` の実績ファイル）がない。**証跡なしのため未実施扱い。**

### 3-2. 全入力経路（単一画像、複数画像、PDF、共有テキスト）の動作確認 — **自動テストは実装済み・実機確認は検証待ち**

根拠（自動）:
- 単一画像: `test/receive_share_handler_test.dart`（単一画像既存フロー）、`ocr_pick_service_intake_result_test.dart`
- 複数画像: 同上（複数画像一括ルーティング）、`document_intake_service_test.dart`（`importImages`）
- PDF: `test/document_intake_service_test.dart`、`test/pdf_pick_service_test.dart`、`test/receive_share_handler_test.dart`
- 共有テキスト: `test/receive_share_handler_test.dart`（`_processText` 相当は直接テストなし）。`text_import_service.dart` / `shared_text_import_controller.dart` は実装されているが専用テストファイルなし

実機/エミュレータでの全経路通し確認の証跡はリポジトリ内に見当たらない（**検証待ち**）。

### 3-3. 取り込み失敗でデータ・一時ファイルが残らないことの確認 — **自動テストで実装済み（実機は検証待ち）**

根拠（自動）:
- `test/document_intake_service_test.dart`
  - 「cooperatively cancels multiple images before the next image」: キャンセル後に `state.documents` 空
  - 「rolls back when cancellation is requested before saving」: 保存直前キャンセルで `document_images` に残存ファイルなし
  - 「removes copied images when database persistence fails」: DB保存失敗で画像ディレクトリ空・`documents` 空
- `test/receive_share_handler_test.dart`「stages local shared files and removes the staging directory」: Staging後始末
- コード: `_runWithStaging` の `finally` 削除、`_saveDocumentWithPages` の `persistedPaths` ロールバック、`pending_file_cleanup` テーブル（`app_database.dart`）、`MainActivity` の失敗時ファイル削除

実機での「取り込み失敗→残骸なし」確認は未実施（**検証待ち**）。

### 3-4. 再起動・アプリ更新後もTodoと通知が維持されることの確認 — **実装あり・受入証跡は検証待ち**

根拠:
- 実装: `ScheduledNotificationBootReceiver`（`BOOT_COMPLETED`/`MY_PACKAGE_REPLACED`/`QUICKBOOT_POWERON`）、`notification_sync_queue`・`pending_file_cleanup` による再試行キュー、`bootstrap_app.dart` の再起動時 `rescheduleAllNotifications`
- 受入証跡: `docs/validation/android-notifications/README.md` は「CONDITIONAL PASS — static and automated validation only」「Androidランタイム上の通知受け入れ検証は未実施（Normal/Reboot/install-r = NOT EXECUTED、接続デバイスなし）」。`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md` は手順書であり実施結果の記録ではない
- 自動: `test/notification_service_test.dart`、`test/notification_schedule_planning_test.dart`、`test/bootstrap_background_task_test.dart` 等でロジックは検証

→ **Issue #136のチェック項目としての「確認」は未完了（検証待ち）**

### 3-5. Drift migration、旧バージョンデータ、購入状態を壊さないことの確認 — **migration/旧データは自動テスト済み・購入状態と実機は検証待ち**

根拠:
- Drift migration（schema v4）: `lib/src/repositories/app_database.dart`（`schemaVersion => 4`、v1→v2→v3→v4 の `onUpgrade`、v3で `db_document_page` 新設、v4で索引、`_repairLegacyReferences`、`_migrateFromPrefs` による旧SharedPreferencesデータ移行＋バックアップ）
- テスト: `test/database_schema_migration_test.dart`（v1→v4 の孤立参照修復、v3→v4 のページ保持）、`test/app_database_test.dart`（schema version 4）
- 購入状態: `purchase_provider` 系テスト（`test/purchase_provider_test.dart` 等）はあるが、「旧バージョンデータ＋購入状態を実機で壊さない」受入証跡はない（**検証待ち**）
- 実機アップグレード検証: `docs/testing/release-device-test-plan.md` DEV-002 は未実施記録（**検証待ち**）

### 3-6. analyze、全テスト、release build、Android実機受入を通過 — **CIゲートは定義済み・受入実績は検証待ち**

根拠:
- `flutter analyze` / `flutter test` / release build（APK・AAB・署名・証明書照合）: `.github/workflows/ci.yml` に定義済み。過去CI成功記録は `docs/validation/android-notifications/logs/git-log.txt`（Flutter CI #754、263 tests、Analyze/Test SUCCESS）にあるが、これはIssue #111時点の記録でv0.7.0機能（PDF/複数画像）マージ後の最新masterのCI実績は本リポジトリ内に記録がない
- Android実機受入: `docs/RELEASE_EXECUTION_PLAN.md` のIssue #60〜#94ゲートは手順・計画のみで、実施済みの受入記録はない（実機での通知受入は未実施と明記）
- `docs/validation/full-source-hardening.md`: PR #119でCI waiver（「latest-head CIは未通過扱い」）があり、master全体の継続的なCI成功を証明するものではない

→ **Issue #136のチェック項目としては「通過」を確認できる証跡が不足（検証待ち）。** `docs/testing/release-device-test-plan.md` は実機テスト手順として存在し、`release-test-results-template.md` が実績記録の雛形。

---

## 4. 未完了項目の残タスクと依存

### 入力経路の強化

| # | 項目 | 状態 | 残タスク | 依存 |
|---|---|---|---|---|
| 1-2 | 複数画像のページ順変更・除外 | 一部実装 | 取り込み前のページ一覧画面（並び替え・除外）を実装し、`importImages` へ適用順を渡す | なし |
| 1-4 | アプリ内画像選択の永続的二重登録防止 | 一部実装 | ギャラリー選択経路にも永続フィンガープリント（バイナリSHA-256等）を付与するか、仕様としてOCRテキスト重複を明文化 | なし |

### 確認画面の修正コスト削減

| # | 項目 | 状態 | 残タスク | 依存 |
|---|---|---|---|---|
| 2-1 | 元文の該当箇所とTodo候補を対応表示 | 未実装 | OCR全文の該当セグメント特定（`_splitCandidateTexts` の区間情報を `ExtractionDraft` へ保持）と、確認画面でのハイライト表示 | `extraction_service.dart` のセグメント区間出力 |
| 2-3 | 同じ誤認識を一括修正 | 未実装 | 候補横断の一括置換（例: タイトル/ラベル/分類の一括適用）UIと `BulkExtractionReviewState` への一括API追加 | 2-1 の対応表示と同一画面での設計が望ましい |
| 2-6 | 辞書反映の取り消しUI | 未実装 | 設定画面に学習ラベル一覧＋個別/一括削除UI。`AppSettings` に個別削除API追加 | なし（`clearLearnedItemLabels` は既存） |

### 検証

| # | 項目 | 状態 | 残タスク | 依存 |
|---|---|---|---|---|
| 3-1 | 実物プリント・スクショ・PDF 30件以上検証 | 検証待ち | 実物素材でのOCR・抽出検証を30件以上実施し証跡を記録 | 実機/エミュレータ、素材 |
| 3-2 | 全入力経路の動作確認 | 検証待ち | 単一画像・複数画像・PDF・共有テキストの実機通し確認＋証跡 | 実機 |
| 3-3 | 取り込み失敗の残骸なし確認 | 検証待ち | 実機で失敗系（空ファイル・大きすぎ・破損・キャンセル）を実行し残骸なしを証跡化 | 実機 |
| 3-4 | 再起動・更新後もTodo/通知維持 | 検証待ち | Issue #60のNormal/Reboot/install-r実測（`docs/RELEASE_VALIDATION_SESSION.md` に従う）を実施し `release-readiness` を得る | emulator-5554 環境、通知権限 |
| 3-5 | migration・旧データ・購入状態の保全 | 検証待ち | 旧版→0.7.0実機アップグレード、購入状態・通知・Todo維持の受入 | 実機、Play内部テスト |
| 3-6 | analyze/全テスト/release build/実機受入 | 検証待ち | v0.7.0マージ後masterのCI成功、release build、実機受入の記録 | 上記すべて＋Play配布 |

## 5. 補足（判定上の注意）

- 「実装済み」はコード・自動テスト・契約テストで確認できたことを意味し、実機/外部ゲートのPASSを意味しません。実機が必要な項目は「検証待ち」にしています。
- `docs/TODO.md` のv0.7.0チェックは「PDF取り込み」「複数画像一括取り込み」「抽出失敗時の手入力移行」のみ `[x]` で、本ドキュメントの判定と一致します（TODO.md の「Android共有経路の改善」「二重登録防止」「起動中/未起動の一貫動作」は `[ ]` のままですが、コード上は実装済みです。TODO.mdの更新は本タスクのスコープ外としました）。
- 実機証跡（`Documents\ashita-release-evidence`）はリポジトリ外のため確認できていません。リポジトリ内の受入記録（`docs/validation/` 配下）ではAndroid通知の実測は「未実施」と明記されています。
