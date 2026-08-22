# Google Play 内部テスト配布

## 結論

- UMP同意対応、共有取り込み、PDF取り込みを含む次の機能リリースは `0.7.0` とする。
- versionCodeは `play_preflight`（Play状態preflight）が実APIから取得した未使用番号を使う。推測で採番せず、衝突時はビルド前にfail-fastする。
- featureブランチから直接配布せず、PRをmasterへマージし、masterのCI成功後に `v0.7.0` タグを付ける。
- **内部テストへ送れるSource SHAは実行時点の最新 `origin/master` と完全一致するcommitだけ**とする。master履歴上にある古いcommitでも拒否する。
- ビルドとアップロードは `.github/workflows/release-android.yml` を正規経路とし、ローカルfastlaneは緊急時・接続確認用に限定する。
- workflow_dispatchの既定値は `validate_only=true` / `release_status=draft`。実uploadは利用者が明示的に安全側の既定値を変更した場合だけ行う。

## 事前ゲート

1. UMP ConsentのPRをmasterへマージする。
2. `pubspec.yaml` の versionCode を自動採番する。**推測で採番しない**。ローカルでは次を実行する（詳細は「バージョン bump フロー」を参照）:

   ```bash
   bundle exec fastlane android play_preflight
   python3 tool/bump_app_version.py --write
   ```

   使用済みversionCodeでPRを開くと `play-state-preflight` job がビルド前にfail-fastで止まる。
3. `Flutter CI` と `Flutter Release Validation` が成功していることを確認する。
4. Android実機で、初回同意、広告表示、プライバシー設定、共有テキスト、画像、PDF、通知、購入復元を確認する。
5. Play Consoleの「アプリのコンテンツ」で、広告、データセーフティ、プライバシーポリシー、対象年齢を最新実装と一致させる。
6. `ANDROID_UPLOAD_CERT_SHA256` が必須Repository Variableとして設定済みであることを確認する。未設定・keystore不一致・AAB signer不一致はいずれもbuild/uploadを継続しない。

## Play 状態 preflight（versionCode / 署名証明書）

`PLAY_SERVICE_ACCOUNT_JSON` でGoogle Play APIへ接続し、ビルド前に実状態を確認するゲートです。

- `bundle exec fastlane android play_preflight`（fastlane lane）: 全トラックのreleaseとAPKから**使用済みversionCode一覧**を取得し、`build/play-release/used-version-codes.json` へ書き出す。
- `python3 tool/play_state_preflight.py`（Pythonツール）: pubspecのversionCodeと照合し、使用済みなら `BLOCKED`（exit 1）でビルドを止め、**次に空いているversionCode**を報告に出す。
- 実施場所:
  - `release-readiness-preflight.yml` の `play-state-preflight` job（pubspec.yaml等を触るPR / master push / 手動実行）
  - `release-android.yml` の `Play release preflight (used versionCode)` ステップ（AABビルド直前）
- 登録済みupload証明書はPlay Developer APIでは取得できない（Play ConsoleのApp integrity画面のみ）。keystore↔`ANDROID_UPLOAD_CERT_SHA256` 照合と、AAB signer↔`ANDROID_UPLOAD_CERT_SHA256` 照合を必須とする。`validate_only` アップロード受理はPlay側登録証明書との追加確認として使う。
- tracks APIは**アクティブなreleaseのみ**を返す。過去のreleaseで使われて廃止（superseded）されたversionCode（例: 4）は一覧に出ないが再利用不可のままなので、次に使う番号は `max(アクティブ)+1` を選ぶ。この意味論は報告JSONの `usedCodesNote` に明記される。

### バージョン bump フロー（推測採番の廃止）

1. `bundle exec fastlane android play_preflight` — Play の使用済み versionCode を実 API から取得し `build/play-release/used-version-codes.json` へ書き出す。
2. `python3 tool/bump_app_version.py --write` — pubspec の現在値と照合し、次空き番号（`max(max(used), 現在値)+1`、現在値が未使用なら維持）を採番して `pubspec.yaml` と `lib/src/app_version.g.dart` を更新する。`--write` を外すと dry-run（変更内容の確認のみ）。
3. 報告JSON（`build/play-release/bump-app-version.json` 等）と推奨commitメッセージを確認し、commit → push → PR する。
4. PR の `play-state-preflight` job が新 versionCode の空きを実 API で再確認する（衝突時は fail-fast）。

## Google Cloud / Play Console サービスアカウント

1. Google Cloud Consoleで専用プロジェクトを作成するか、既存のリリース用プロジェクトを選ぶ。
2. Google Play Android Developer APIを有効にする。
3. IAMと管理 > サービス アカウントで、リリース専用サービスアカウントを作成する。
4. 鍵 > 鍵を追加 > 新しい鍵を作成 > JSON を選び、一度だけJSON鍵をダウンロードする。
5. Play Console > ユーザーと権限 > 新しいユーザーを招待し、サービスアカウントのメールアドレスを追加する。
6. アプリ権限は `あしたもつもの` のみに限定する。
7. 権限は最低限「アプリ情報の表示」と「テストトラックへのリリース」を付与する。テスター一覧も自動管理する場合だけ「テストトラックの管理」を追加する。Production公開権限と管理者権限は付与しない。
8. JSON鍵を平文ファイル共有、Issue、PR、ログへ貼り付けない。

## GitHub Actions設定

Repository settings > Secrets and variables > Actions で設定する。

### Secrets

- `PLAY_SERVICE_ACCOUNT_JSON`: ダウンロードしたJSON鍵の内容全体
- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`
- `GEMINI_PROXY_URL`

### Variables

- `ANDROID_UPLOAD_CERT_SHA256`（**必須**。空値ではrelease workflowを開始しない）
- `IAP_REMOVE_ADS_PRODUCT_ID`
- `IAP_AI_ACCESS_PRODUCT_ID`

`google-play-internal` Environmentを作成し、必要ならrequired reviewersを設定する。Environment secretsへ移す場合も、ワークフローで参照する名前は同じにする。

## Play Console 内部テスト設定

1. Play Consoleで `あしたもつもの` を開く。
2. テストとリリース > テスト > 内部テストを開く。
3. テスタータブで「メールリストを作成」を選び、GoogleアカウントまたはGoogle Workspaceのメールアドレスを追加する。内部テストは最大100人。
4. 変更を保存し、表示されたオプトインURLをテスターへ共有する。
5. アプリ内課金を試すアカウントは、設定 > ライセンステストにも追加する。
6. 初回リリースでは、ストア掲載情報、アプリのコンテンツ、国/地域、価格、Play App Signingの未完了項目を解消する。

## 推奨リリース手順

1. featureブランチのローカル変更を確認し、意図したファイルだけコミットしてpushする。
2. feature PRのCIとレビューを完了し、masterへsquash mergeする。
3. リリースPRで `pubspec.yaml` の versionCode を「バージョン bump フロー」（`bump_app_version.py`）で採番し、`fastlane/metadata/android/ja-JP/changelogs/default.txt` を実際の変更内容へ更新する。
4. リリースPRをmasterへマージし、masterのCI成功を確認する。
5. タグ作成直前に `git fetch origin master --force` と `git rev-parse HEAD origin/master` を確認し、HEADと最新`origin/master`が完全一致していることを確認する。
6. `git tag v0.7.0` と `git push origin v0.7.0` を実行する。
7. GitHub Actionsの `Android Internal Release` が、**Source SHA == 最新origin/master**、Play状態preflight（versionCode未使用・証明書照合）、AAB生成、Google Play API認証、internalトラックへのアップロードまで成功することを確認する。versionCodeが使用済みの場合はpreflightがビルド前に失敗するので、pubspecのbuild番号を次の空き番号へ更新して再実行する。
8. Play Consoleの内部テストリリース画面でversionName/versionCode、リリースノート、対象デバイス除外、事前審査の警告を確認する。
9. テスター端末でオプトインURLを開き、Google Play経由でインストール・更新する。

タグを作る前の疎通確認には、Actionsのworkflow_dispatchを使う。**既定値の `validate_only=true` / `release_status=draft` のままではpublishしない**。実配布する場合だけ、最新origin/masterとの一致を再確認した上で `validate_only=false` と意図するrelease statusを明示的に選ぶ。

## ローカルfastlane

ローカル実行はCI障害時の予備経路とする。秘密鍵をリポジトリ配下へ置かない。

```bash
bundle install
export PLAY_SERVICE_ACCOUNT_JSON_PATH=/secure/path/play-service-account.json
export ANDROID_AAB_PATH=build/app/outputs/bundle/release/app-release.aab
bundle exec fastlane android validate_play_credentials
bundle exec fastlane android play_preflight
python3 tool/bump_app_version.py --write
bundle exec fastlane android internal
```

AABは既存の署名設定を使って生成する。versionCodeは `bump_app_version.py` が `play_preflight` の取得結果から採番する（推測しない）。

## ロールバック

Google Playでは使用済みversionCodeを再利用できない。問題があれば内部テストリリースを停止し、`play_preflight` が提示する次の空きversionCodeで修正版を再アップロードする。署名鍵やサービスアカウント鍵が漏えいした場合は、対象鍵を直ちに無効化・削除し、GitHub Secretを更新する。
