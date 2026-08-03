# OCR品質評価（担当B）

## 目的

「OCRが改善されている」という定性的評価を、実データによる定量評価へ変える。

## データ取扱い（必須）

- 実プリントは**repository外のローカル領域**だけで使用する。
- 原本、OCR全文、児童名、学校名、住所、電話番号、QRコード等を**GitHubへ保存しない**。
- スクリーンショットやログを残す場合は**完全匿名化**する。
- 通常OCRの画像を**外部送信しない**。
- AI画像解析（Gemini等）と通常OCRは**分離して評価**する。

## 現状（2026-08-03）

**BLOCKED: 実プリントデータが利用できない。**

- `C:\Users\neoen\Documents\ashita-release-evidence`（`normal` のみ、画像1枚）
- `C:\Users\neoen\OneDrive\Documents\ashita-release-evidence`（`normal`, `SETUP_ENV` のみ）
- `C:\Users\neoen\Downloads`、`C:\Users\neoen\Pictures` に実プリントなし

代替データを勝手に作って「品質達成」扱い**しない**。以下は評価基盤の整備のみ。

## 評価手順

### 1. データセット収集

利用可能なら30件以上を評価する。内訳の目安:

- 印刷された通常のお便り
- 表形式
- 複数ページ
- PDF
- スクリーンショット
- 写真撮影
- 斜め・影・低コントラスト
- 小さい文字
- 手書き混在

### 2. 計測項目（各文書ごと）

| 項目 | キー |
|---|---|
| 入力形式 | `input_type` |
| ページ数 | `page_count` |
| OCR成功/失敗 | `ocr_success` |
| 候補件数 | `candidate_count` |
| 正しい日付候補数 | `correct_date_candidates` |
| 誤った日付候補数 | `wrong_date_candidates` |
| 正しい持ち物・提出物・集金候補数 | `correct_item_candidates` |
| 不要候補数 | `unnecessary_candidates` |
| 抽出漏れ数 | `missing_extractions` |
| 修正なしで登録できたか | `registered_without_edit` |
| 修正操作回数 | `edit_count` |
| 処理時間 | `processing_time_seconds` |
| クラッシュ・freeze・OOM | `crash_or_freeze` |
| 手入力へのフォールバック可否 | `manual_fallback_possible` |

### 3. 集計指標

- 取り込み成功率
- OCR空結果率
- 日付抽出 precision / recall
- 持ち物等の precision / recall
- 修正なし登録率
- 1文書あたり平均修正回数
- 平均 / p95 処理時間
- クラッシュ率
- 入力形式別の結果

母数が少ない場合は、小数点以下の精密な率を品質保証として扱わない。

### 4. 合否基準（暫定目標）

| 指標 | 目標 |
|---|---|
| 取り込み成功率 | 95%以上 |
| クラッシュ / データ破損 | 0件 |
| 通常印刷文書で修正なし登録率 | 70%以上 |
| 手動修正後に登録可能 | 95%以上 |
| OCR失敗後に手入力へ移行可能 | 100% |
| p95処理時間 | 利用不能な長さでないこと |
| 誤った期限を無確認で自動登録 | しないこと |

既存文書（docs等）に正式基準があればそちらを優先する。この数値を満たさなくても、勝手にテストや基準を弱めない。原因と改善案を報告する。

### 5. 実行手順

1. 実プリントを匿名化してローカル領域（`C:\Users\neoen\Documents\ashita-ocr-dataset` 等、repository外）へ配置
2. `test_driver/ocr_verify.dart` を参照して、各画像の OCR → 抽出 → 結果記録を実施
3. `tool/ocr_benchmark/benchmark_template.json` に匿名集計を記録
4. 集計指標を算出し、合否基準と照合
5. 結果を Issue #136 の検証項目（30件以上検証）へ反映

### 6. 再開条件

- 実プリント30件以上（または利用可能な範囲）が repository 外のローカル領域に用意されること
- エミュレータ / 実機で OCR パイプラインが実行できること
