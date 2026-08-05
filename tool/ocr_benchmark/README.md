# OCRベンチマーク実行手順

`docs/OCR_BENCHMARK.md`のデータ取扱いと評価基準に従い、実プリント原本はリポジトリ外で管理します。

## 1. 入力データ

実プリント、PDF、スクリーンショットは匿名化し、例えば次のようなリポジトリ外ディレクトリへ置きます。

```text
C:\Users\neoen\Documents\ashita-ocr-dataset\
```

GitHubへ保存してはいけないもの：

- 原本画像・PDF
- OCR全文・元文
- 児童名、学校名、教員名
- 住所、電話番号、メールアドレス
- QRコード
- ローカルファイルパス

## 2. 1文書ずつ確認する

実機またはエミュレータへ匿名化済み画像を転送し、既存ハーネスまたはアプリ画面から確認します。

```bash
adb push <image> /sdcard/Download/test_ocr.png
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=test_driver/ocr_verify.dart
```

`test_driver/ocr_verify.dart`はOCR全文を標準出力へ表示するため、実行ログをGitHubへ添付しません。記録するのは匿名化された数値・真偽値だけです。

## 3. 記録ファイルを作る

`benchmark_template.json`をリポジトリ外へコピーし、`documents`へ1件ずつ記録します。テンプレートには架空の実績値を入れていません。

各文書で必須の主な値：

- 入力形式・ページ数
- 取り込み、OCR、空結果の成否
- 正解／誤検出／期待される日付・持ち物件数
- 不要候補、抽出漏れ、修正回数
- 修正なし登録、手動修正後登録、手入力フォールバック
- 処理時間、クラッシュ、データ破損
- 誤った期限を無確認で自動登録したか

`dataset.count`と`documents`の件数を一致させます。

## 4. 検証・集計する

```bash
python3 tool/ocr_benchmark/summarize.py \
  C:\Users\neoen\Documents\ashita-ocr-dataset\benchmark.json \
  --output C:\Users\neoen\Documents\ashita-ocr-dataset\summary.json
```

品質ゲートとしてPASSを要求する場合：

```bash
python3 tool/ocr_benchmark/summarize.py benchmark.json --require-pass
```

終了コード：

- `0`: 入力は有効。`--require-pass`使用時はPASS
- `2`: JSON、スキーマ、個人情報キー、整合性のエラー
- `3`: `--require-pass`使用時にBLOCKEDまたはFAIL

## 5. 判定

- 30件未満、または印刷文書が0件：`BLOCKED`
- 30件以上で閾値違反：`FAIL`
- 30件以上で自動閾値を満たす：`PASS`

p95処理時間は自動的に数値判定しません。実際の操作性と端末条件を併記して人が評価します。

人工fixtureや自動テストだけで、実プリント30件の品質ゲートをPASS扱いにしません。
