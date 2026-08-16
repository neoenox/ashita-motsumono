# v0.7.0 受入状況

基準日：2026-08-16
対象master：`b010a9d646182e9591b269d8731b60f02ffb860b`
アプリバージョン：`0.7.0+3`  
関連Issue：#60、#59、#98、#94、#136、#146

## 結論

判定は`KEEP_BLOCKED_EXTERNAL_ACCEPTANCE`です。

コード統合、Flutter Analyze、全Flutter test、署名済みRelease APK/AABの生成・証明書照合、release manifest生成は、現行masterのCIで成功しています。Play Consoleのクローズドテスト(Alpha)ではv0.7.0が公開中です。一方、実プリント30件以上、全入力経路の実機通し確認、通知のNormal/Reboot/install-r、旧版アップグレード、購入復元、本番提出は未完了です。さらに、現行masterからのPlay再配布（`Android Internal Release`）はkeystore証明書フィンガープリント不一致で失敗しており、署名鍵の整合性確認が新たな必須ブロッカーです。

## クローズドテスト(Alpha) 公開状況

- v0.7.0（`0.7.0+3`）がクローズドテスト(Alpha)トラックで公開中（2026-08-10 1:49 公開、審査完了）
- アップロードは run `30360560641`（2026-07-28、`fa73fdb416`）の成果物
- テスター: Google Group `aimitsumori-testers`（1名登録済み、2026-08-14 確認）
- 本番公開にはクローズドテスト14日間継続・テスター12人達成が要件（TODO.md）
- これは本番提出・実機受入の証跡ではありません

## 署名鍵の整合性ブロッカー（2026-08-16 発見）

`Android Internal Release` workflow が master 履歴上のコミット `5ad77e62a3` / `9f73ee23c3` で失敗しています（run `31587962315` / `31591654675`、2026-08-12）。

- 失敗ステップ: `Verify *** keystore certificate`
- 期待値: `ANDROID_UPLOAD_CERT_SHA256` = `DF:5B:D8:9F:29:C4:4B:EC:FA:C1:48:3A:00:29:52:16:80:19:89:72:BA:A4:C0:7F:4F:4F:81:AD:EF:D6:91:E6`
- 実測: `8D:BE:CD:58:FA:97:6D:3C:22:3C:38:A5:1C:0D:FB:80:6D:7E:AC:10:E3:22:DF:D8:92:2D:B4:8C:2C:B6:30:E8`

現在のキーストアと登録済みアップロード証明書のどちらが正か確認できるまで、Play再配布・`formalRelease`・本番提出は進められません。Secrets／Variablesの値変更は外部環境の人間操作です。

## 最新の自動品質ゲート

現行masterの検証対象HEAD：`b010a9d646182e9591b269d8731b60f02ffb860b`（2026-08-14、#170 merge 後）

- Release Automation Validation `31771720995`: SUCCESS
- Flutter Release Validation `31771721000`: SUCCESS
- Flutter CI `31771720982`: SUCCESS
  - Dart format
  - Analyze
  - 全Flutter test
  - 署名済みrelease APK/AAB build
  - APK/AAB/キーストア証明書のSHA-256照合
  - release manifest生成
  - 署名APK/AAB・evidence artifactのupload

`31771721000`のrelease manifestは対象master SHA、version `0.7.0+3`、Application ID、証明書照合結果を記録しています。これは自動artifactの証跡であり、Play Consoleへのupload・実機受入の証跡ではありません。

## 入力経路

| 項目 | 状態 | 備考 |
|---|---|---|
| PDF取り込み | 実装済み | 複数ページ、検証、重複防止、ロールバックの自動テストあり |
| 複数画像一括取り込み | 実装済み | 取り込み前のページ並び替え・除外UIと自動テストあり。実機通し確認は未完了 |
| Android共有 | 実装済み | テキスト、画像、複数画像、PDFを処理。各共有元アプリからの実機通し確認は未完了 |
| PDF二重登録防止 | 実装済み | SHA-256 fingerprint |
| 画像・テキスト重複抑止 | 実装済み | OCRテキスト指紋とセッションTTL。全経路の永続バイナリ重複判定ではない |
| 起動中・未起動の共有処理 | 実装済み | 同一処理キューへ合流。実機受入は未完了 |

## 確認画面

| 項目 | 状態 | 備考 |
|---|---|---|
| 候補ごとの編集 | 実装済み | 日付、種類、金額、持ち物、通知等 |
| 一括置換 | 実装済み | タイトル／持ち物。CI回帰テストを追加 |
| 複数選択・削除 | 実装済み | 空状態とOCR参照同期をCI回帰テストで確認 |
| 候補ゼロ時の手入力 | 実装済み | NoCandidatesScreen |
| 元文と候補の対応ハイライト | 未実装 | OCR区間情報と表示設計が必要 |
| 学習辞書の取り消しUI | 実装済み | 個別削除、SnackBarからのUndo、全消去と自動テストあり |

## UMP・初回導線・辞書

| 項目 | 状態 | 備考 |
|---|---|---|
| UMP同意・広告初期化 | 自動テスト済み／実機未完了 | timeout、失敗時のfail-closed、広告可否、プライバシー設定入口をコードとテストで確認。初回同意、広告表示、設定変更はAndroid実機未確認 |
| 通知の初回説明 | 実装済み／実機未完了 | `notification_info_shown_v1`で説明表示と「あとで」／有効化を制御。Android通知権限、再起動、更新後の実測はIssue #60で未完了 |
| 初回onboarding完了状態 | 要仕様確認 | `onboarding_completed_v1`は本番`lib`から参照されず、人物未登録時カードとは別の専用完了フローになっていない。未確認をPASSにしない |
| 学習辞書の取消 | 自動テスト済み／実機未完了 | 個別削除、Undo、全消去を確認。永続化失敗時のrollbackはサービス側で保持。実端末UXは未確認 |

## 継続する回帰テスト

旧PR #147の人工fixtureテストは実機受入そのものではありません。価値のある部分を通常の`flutter test`対象へ移し、次を継続検証します。

- 120候補の表示と末尾スクロール
- 全選択、全解除、単一選択
- 全削除後の空状態とOCR参照同期
- タイトル／持ち物の一括置換
- 空検索、該当なし検索
- 長い日本語文字列のレイアウト例外

このテストはAndroid実機、IME、回転、アクセシビリティ文字倍率、端末性能の検証を代替しません。

## 検証状況

| 検証 | 状態 | 完了条件 |
|---|---|---|
| 実プリント等30件以上 | BLOCKED | リポジトリ外の匿名化データで`docs/OCR_BENCHMARK.md`を実施 |
| 単一画像・複数画像・PDF・共有テキスト | 自動テスト済み／実機未完了 | 実機またはAVDで全経路を通し、証跡を残す |
| 失敗時のDB・一時ファイル残存なし | 自動テスト済み／実機未完了 | 破損、過大、キャンセル、画面離脱を実機確認 |
| 通知の再起動・更新維持 | BLOCKED | Issue #60のNormal/Reboot/install-r集約PASS |
| Drift migration | 自動テスト済み | 旧版アプリからの実機アップグレードを追加確認 |
| 購入状態 | ライフサイクル回帰テスト済み | Play経由の購入・復元・アップグレード確認 |
| Analyze／全test／署名済みRelease artifact | PASS_AUTOMATED | run `31771720982`/`31771721000`で現行master、署名・証明書照合・manifest生成まで完了 |
| クローズドテスト(Alpha)配布 | 公開済み | v0.7.0を2026-08-10に公開（07-28アップロードのrun `30360560641`）。テスター1名 |
| Play再配布（Android Internal Release） | BLOCKED | 08-12にkeystore証明書不一致で失敗（run `31591654675`）。`ANDROID_UPLOAD_CERT_SHA256`とキーストアの整合を確認 |
| Play App Signing／upload証明書のConsole照合 | BLOCKED | Repository VariableとCI artifactの照合は確認済み。Play Console画面の外部証跡は未確認 |
| Play内部テスト（本番版） | BLOCKED | 現行masterでAndroid Internal Releaseの新規成功run、Play upload、Play経由インストールを未確認 |
| release orchestrator `--report-only` | KEEP_BLOCKED | cleanな現行masterとartifact manifestで実行。Issue #60、Play signing、formalRelease、Play submission、internalTestの外部証跡不足 |
| Android実機最終受入 | BLOCKED | 物理端末または承認された受入環境で完了 |

## OCR品質評価

評価手順：`docs/OCR_BENCHMARK.md`  
記録テンプレート：`tool/ocr_benchmark/benchmark_template.json`  
検証・集計：`tool/ocr_benchmark/summarize.py`

人工データやCIだけで「30件検証済み」と扱いません。

## 残タスクの優先順位

1. **keystore証明書の整合性確認**（`ANDROID_UPLOAD_CERT_SHA256`と現行キーストアの不一致解消）— Play再配布・formalReleaseの前提
2. Issue #60の通知実測（current master `b010a9d646…` で再実行）
3. 匿名化済み実プリント等30件以上のOCRベンチマーク
4. 全入力経路と失敗経路の実機通し確認
5. 旧版→0.7.0アップグレードと購入復元
6. Play App SigningのConsole証跡、正式artifactの運用判断、本番内部テスト
7. 元文対応表示と初回onboarding完了状態の仕様判断

## 判定ルール

- 自動ゲート成功：`PASS_AUTOMATED`
- 外部・実機証跡不足：`KEEP_BLOCKED_EXTERNAL_ACCEPTANCE`
- 実機・Playを含む全条件完了後のみ、Issue #136 Close候補とする
