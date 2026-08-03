# OCRベンチマーク実行手順

`docs/OCR_BENCHMARK.md` の評価手順に従う。

## 前提

- Flutter 3.44.0 / Dart 3.12.0
- 実プリント画像（repository外のローカル領域）
- エミュレータ（emulator-5554）または実機

## 実行

### 1. 実プリントを匿名化して配置

```
C:\Users\neoen\Documents\ashita-ocr-dataset\  （repository外）
```

児童名・学校名・住所・電話番号・QRコードを黒塗り/切り取りで匿名化する。

### 2. OCRハーネスで1文書ずつ評価

`test_driver/ocr_verify.dart` を参考に、画像を `/sdcard/Download/` へ push して実行:

```bash
adb push <image> /sdcard/Download/benchmark.png
flutter drive --driver=test_driver/integration_test.dart --target=test_driver/ocr_verify.dart
```

またはアプリのOCR導線（画像選択 → 候補確認）で手動評価。

### 3. 匿名集計を記録

`tool/ocr_benchmark/benchmark_template.json` をコピーして各文書を記録する。

### 4. 集計と判定

- 取り込み成功率 = 取り込み成功文書数 / 全文書数
- 日付 precision = 正しい日付候補数 / 日付候補総数
- 日付 recall = 正しい日付候補数 / 正解日付総数
- 修正なし登録率 = 修正なし登録文書数 / 全文書数
- p95処理時間 = 処理時間の95パーセンタイル

`docs/OCR_BENCHMARK.md` の合否基準と照合する。

## 禁止事項

- 実プリント・OCR全文・個人情報をGitHubへpushしない
- 通常OCRの画像を外部送信しない
- 人工fixtureだけで「品質達成」としない
