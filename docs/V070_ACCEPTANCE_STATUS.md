# v0.7.0 受入状況

基準日：2026-08-05  
対象master：`e5fe676443319f55b2be5302aae322d1b5c6677e`  
アプリバージョン：`0.7.0+3`  
関連Issue：#136、#146

## 結論

判定は`KEEP_BLOCKED_EXTERNAL_ACCEPTANCE`です。

コード統合、Flutter Analyze、全Flutter test、Release APK/AAB build、artifact検証は成功しています。一方、実プリント30件以上、全入力経路の実機通し確認、通知のNormal/Reboot/install-r、旧版アップグレード、購入復元、Play配布は未完了です。

## 最新の自動品質ゲート

統合PR #158の検証対象HEAD：`c75b4ebad058228b7f4c3020eab93387d459e9f0`

- Release Automation Validation `30974846475`: SUCCESS
- Flutter CI `30974846504`: SUCCESS
- Flutter Release Validation `30974846503`: SUCCESS
  - Dart format
  - Analyze
  - 全Flutter test
  - Android platform再生成
  - release APK build
  - release AAB build
  - artifact verification/upload

PR #158はsquash merge済みです。

- master commit：`e5fe676443319f55b2be5302aae322d1b5c6677e`
- merge後`flutter-ci-master`：SUCCESS
- master run：`30978701905`

## 入力経路

| 項目 | 状態 | 備考 |
|---|---|---|
| PDF取り込み | 実装済み | 複数ページ、検証、重複防止、ロールバックの自動テストあり |
| 複数画像一括取り込み | 一部実装 | 一括処理は実装済み。取り込み前のページ並び替え・除外UIは未実装 |
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
| 学習辞書の取り消しUI | 未実装 | 全削除以外の一覧・個別削除UIが必要 |

## 2026-08-05に追加する回帰テスト

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
| Analyze／全test／Release build | PASS | 最新統合HEADで完了 |
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
5. Play署名、正式Release、内部テスト
6. 元文対応表示、辞書取り消しUI、ページ並び替え・除外UIの実装判断

## 判定ルール

- 自動ゲート成功：`PASS_AUTOMATED`
- 外部・実機証跡不足：`KEEP_BLOCKED_EXTERNAL_ACCEPTANCE`
- 実機・Playを含む全条件完了後のみ、Issue #136 Close候補とする
