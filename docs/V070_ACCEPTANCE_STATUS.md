# v0.7.0 受入状況

基準日：2026-08-06
対象master：`b51ed3c6285976344fb3625dbdb3765150787e8f`
アプリバージョン：`0.7.0+3`  
関連Issue：#60、#59、#98、#94、#136、#146

## 結論

判定は`KEEP_BLOCKED_EXTERNAL_ACCEPTANCE`です。

コード統合、Flutter Analyze、全Flutter test、署名済みRelease APK/AABの生成・証明書照合、release manifest生成は、現行masterのCIで成功しています。一方、実プリント30件以上、全入力経路の実機通し確認、通知のNormal/Reboot/install-r、旧版アップグレード、購入復元、Play Console内部テストは未完了です。

## 最新の自動品質ゲート

現行masterの検証対象HEAD：`b51ed3c6285976344fb3625dbdb3765150787e8f`

- Release Automation Validation `31057386580`: SUCCESS
- Release Readiness Preflight `31057386919`: SUCCESS
- Flutter Release Validation `31057384779`: SUCCESS
- Flutter CI `31088423419`: SUCCESS（masterへのworkflow_dispatch）
  - Dart format
  - Analyze
  - 全Flutter test
  - 署名済みrelease APK/AAB build
  - APK/AAB/キーストア証明書のSHA-256照合
  - release manifest生成
  - 署名APK/AAB・evidence artifactのupload

`31088423419`のrelease manifestは対象master SHA、version `0.7.0+3`、Application ID、証明書照合結果を記録しています。これは自動artifactの証跡であり、Play Consoleへのupload・内部テスト・実機受入の証跡ではありません。

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
| Analyze／全test／署名済みRelease artifact | PASS_AUTOMATED | run `31088423419`で現行master、署名・証明書照合・manifest生成まで完了 |
| Play App Signing／upload証明書のConsole照合 | BLOCKED | Repository VariableとCI artifactの照合は確認済み。Play Console画面の外部証跡は未確認 |
| Play内部テスト | BLOCKED | 現行masterでAndroid Internal Releaseの新規成功run、Play upload、Play経由インストールを未確認 |
| release orchestrator `--report-only` | KEEP_BLOCKED | cleanな現行masterとartifact manifestで実行。Issue #60、Play signing、formalRelease、Play submission、internalTestの外部証跡不足 |
| Android実機最終受入 | BLOCKED | 物理端末または承認された受入環境で完了 |

## OCR品質評価

評価手順：`docs/OCR_BENCHMARK.md`  
記録テンプレート：`tool/ocr_benchmark/benchmark_template.json`  
検証・集計：`tool/ocr_benchmark/summarize.py`

人工データやCIだけで「30件検証済み」と扱いません。

## 残タスクの優先順位

1. Issue #60の通知実測
2. 匿名化済み実プリント等30件以上のOCRベンチマーク
3. 全入力経路と失敗経路の実機通し確認
4. 旧版→0.7.0アップグレードと購入復元
5. Play App SigningのConsole証跡、正式artifactの運用判断、内部テスト
6. 元文対応表示と初回onboarding完了状態の仕様判断

## 判定ルール

- 自動ゲート成功：`PASS_AUTOMATED`
- 外部・実機証跡不足：`KEEP_BLOCKED_EXTERNAL_ACCEPTANCE`
- 実機・Playを含む全条件完了後のみ、Issue #136 Close候補とする
