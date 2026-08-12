# あしたもつもの

園・学校・習い事のプリント、スクリーンショット、連絡文から、今日・明日の持ち物・提出物・集金をTodo化するFlutterアプリです。

## 対象プラットフォーム

現行MVPは Android / iOS を対象とします。日本語OCRは Google ML Kit Text Recognition を使用します。

Web / Windows / macOS / Linux は現行MVPの対象外です。

## 主な機能

- 子ども情報の登録・編集
- Todoの手入力、編集、完了、削除
- カメラ / 画像 / 複数画像 / PDF / Android共有からの取り込み
- 日本語OCRとTodo候補抽出
- 登録前の確認・修正、一括編集、重複防止
- 今日 / 明日 / 未設定 / 今後のTodo表示
- ローカル通知予約と再予約
- Drift / SQLiteによる端末内保存
- 保存データの移行・破損時の復旧
- JSONエクスポートと全データ削除
- 広告除去・AI解析のアプリ内課金
- 任意のAI画像解析をCloudflare Workers経由で実行

## アーキテクチャとプライバシー

- ログインなし
- 家族共有 / Todoクラウド同期なし
- 通常OCRは端末内処理
- 画像の恒久クラウド保存なし
- 購入検証と任意AI解析だけCloudflare Workersを使用
- AI解析画像は利用者の確認・同意後に送信
- DB、画像、購入cache等はAndroidのクラウドbackup対象外

詳細: `docs/privacy_policy.md`

## 必要環境

- Flutter 3.44.0（`.fvmrc` / CIを正とする）
- Dart 3.12.0以上
- Java 17
- Android SDK / Xcode

## セットアップ

```bash
bash tool/create_platforms.sh
flutter pub get
```

ネイティブ設定は `docs/NATIVE_SETUP.md` を参照してください。

## 開発

通常機能:

```bash
flutter run
```

AI画像解析を含む開発では必要な `--dart-define` を指定します。秘密値や本番credentialをコマンド履歴・Issue・PRへ記録しないでください。

## 品質ゲート

```bash
flutter analyze --no-fatal-infos
flutter test
python3 -m unittest tool/test_generate_release_manifest.py
python3 -m unittest tool/test_release_workflow.py
git diff --check
```

変更範囲に応じて、Android build、release automation、OCR / intake / notification / billing のfocused testも実行します。

## Cloudflare Workers

`workers/gemini-proxy` は主に次を提供します。

- `POST /entitlements/verify` — store購入証明の検証
- `POST /analyze` — 短命アクセストークンを要求するAI画像解析
- `GET /health` — 非機微な稼働確認

詳細: `workers/gemini-proxy/README.md`

Worker Secretsやstore service accountは、repositoryやログへ保存しません。

## Android release

正式releaseでは、source SHA、署名、application ID、version、APK/AAB hash、課金商品IDなどを `release-manifest.json` に記録し、同一release session内で検証します。

代表的な成果物:

- `ashita-motsumono-signed-release-apk`
- `ashita-motsumono-signed-release-aab`
- `ashita-motsumono-release-evidence`

### Release gate順序

releaseは次の順序で受入します。

```text
通知再予約の実環境受入
→ Play upload signing確認
→ 正式署名APK/AAB生成
→ Play Console提出準備
→ 内部テスト
```

過去の別SHAで取得した実機・署名・Play証跡を、current release sessionのPASSとして流用しません。

## 高リスク境界

次はコード変更とは別の明示承認が必要です。

- keystore / upload key の作成・再発行
- GitHub Secrets / Variables の変更
- Cloudflare Worker Production Secrets / deploy
- Play Console設定、商品作成、内部テストupload、審査提出
- Production公開

## 作業管理

READMEには変動しやすいcurrent SHA、Issue番号、Play受入結果を固定しません。最新のrelease chain、実機acceptance、store blockerは GitHub Issues / Pull Requests と `docs/RELEASE_VALIDATION_SESSION.md` / `docs/RELEASE_EXECUTION_PLAN.md` を正としてください。
