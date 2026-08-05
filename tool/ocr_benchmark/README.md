# OCRベンチマーク実行手順

`docs/OCR_BENCHMARK.md`のデータ取扱いと評価基準に従い、実プリント原本はリポジトリ外で管理します。

## 1. 入力データ

実プリント、PDF、スクリーンショットは匿名化し、例えば次のようなリポジトリ外ディレクトリへ置きます。

```text
C:\Users\<user>\Documents\ashita-ocr-dataset\
```

GitHubへ保存してはいけないもの：

- 原本画像・PDF
- OCR全文・元文
- 児童名、学校名、教員名
- 住所、電話番号、メールアドレス
- QRコード
- ローカルファイルパス
- 個人を再識別できる任意の文字列

## 2. 1文書ずつ確認する

実機またはエミュレータへ匿名化済み画像を転送し、既存ハーネスまたはアプリ画面から確認します。

```bash
adb push <image> /sdcard/Download/test_ocr.png
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=test_driver/ocr_verify.dart
```

`test_driver/ocr_verify.dart`はOCR全文を標準出力へ表示するため、実行ログをGitHubへ添付しません。記録するのは、固定列の匿名ID・入力種別・数値・真偽値だけです。

## 3. 記録ファイルを作る

`benchmark_template.json`をリポジトリ外へコピーし、`documents`へ1件ずつ記録します。テンプレートには架空の実績値や集計結果を入れていません。

### 厳格な入力スキーマ

トップレベルで許可されるキーは次の3つだけです。

- `schema_version`
- `dataset`
- `documents`

`dataset`で許可されるキー：

- `source`
- `count`

各文書で許可されるキー：

- `id`: `DOC-001`から`DOC-999999`までの匿名ID
- `input_type`
- `page_count`
- `ingest_success`
- `ocr_success`
- `ocr_empty`
- `candidate_count`
- `correct_date_candidates`
- `wrong_date_candidates`
- `expected_date_count`
- `correct_item_candidates`
- `wrong_item_candidates`
- `expected_item_count`
- `unnecessary_candidates`
- `missing_extractions`
- `registered_without_edit`
- `manual_edit_then_registrable`
- `edit_count`
- `processing_time_seconds`
- `crash_or_freeze`
- `data_corruption`
- `manual_fallback_possible`
- `unconfirmed_wrong_due_date_auto_register`

未知キー、自由記述欄、集計済み`metrics`／`verdict`、個人名風IDはすべて拒否されます。`dataset.count`と`documents`の件数を一致させます。

## 4. 検証・集計する

```bash
python3 tool/ocr_benchmark/summarize.py \
  C:\Users\<user>\Documents\ashita-ocr-dataset\benchmark.json \
  --output C:\Users\<user>\Documents\ashita-ocr-dataset\summary.json
```

品質ゲートとしてPASSを要求する場合：

```bash
python3 tool/ocr_benchmark/summarize.py benchmark.json --require-pass
```

終了コード：

- `0`: 入力は有効。`--require-pass`使用時はPASS
- `2`: JSON、厳格スキーマ、匿名ID、型、件数、成否・候補数整合性のエラー
- `3`: `--require-pass`使用時にBLOCKEDまたはFAIL

## 5. 判定

- 30件未満、または印刷文書が0件：`BLOCKED`
- 30件以上で閾値違反：`FAIL`
- 30件以上で自動閾値を満たす：`PASS`

p95処理時間は自動的に数値判定しません。実際の操作性と端末条件を併記して人が評価します。

人工fixtureや自動テストだけで、実プリント30件の品質ゲートをPASS扱いにしません。
