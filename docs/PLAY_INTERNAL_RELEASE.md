# Google Play 内部テスト配布

## 結論

- UMP同意対応、共有取り込み、PDF取り込みを含む次の機能リリースは `0.7.0` とする。
- Play ConsoleのversionCodeは必ず増加させるため、現行 `0.6.3+2` の次は原則 `0.7.0+3` とする。ただしPlay ConsoleにversionCode 3以上が既に存在する場合は、それより大きい番号へ上げる。
- featureブランチから直接配布せず、PRをmasterへマージし、masterのCI成功後に `v0.7.0` タグを付ける。
- ビルドとアップロードは `.github/workflows/release-android.yml` を正規経路とし、ローカルfastlaneは緊急時・接続確認用に限定する。

## 事前ゲート

1. UMP ConsentのPRをmasterへマージする。
2. `pubspec.yaml` を `version: 0.7.0+3` へ更新する。Play Consoleの最新versionCodeが3以上なら、`+4` など未使用の値にする。
3. `Flutter CI` と `Flutter Release Validation` が成功していることを確認する。
4. Android実機で、初回同意、広告表示、プライバシー設定、共有テキスト、画像、PDF、通知、購入復元を確認する。
5. Play Consoleの「アプリのコンテンツ」で、広告、データセーフティ、プライバシーポリシー、対象年齢を最新実装と一致させる。

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

- `ANDROID_UPLOAD_CERT_SHA256`
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
3. リリースPRで `pubspec.yaml` を `0.7.0+3` へ更新し、`fastlane/metadata/android/ja-JP/changelogs/default.txt` を実際の変更内容へ更新する。
4. リリースPRをmasterへマージし、masterのCI成功を確認する。
5. `git tag v0.7.0` と `git push origin v0.7.0` を実行する。
6. GitHub Actionsの `Android Internal Release` が、master包含確認、署名確認、AAB生成、Google Play API認証、internalトラックへのアップロードまで成功することを確認する。
7. Play Consoleの内部テストリリース画面でversionName/versionCode、リリースノート、対象デバイス除外、事前審査の警告を確認する。
8. テスター端末でオプトインURLを開き、Google Play経由でインストール・更新する。

タグを作る前の疎通確認には、Actionsのworkflow_dispatchで `validate_only=true` を選ぶ。実配布はmaster上で `validate_only=false`、通常は `release_status=completed` を使用する。

## ローカルfastlane

ローカル実行はCI障害時の予備経路とする。秘密鍵をリポジトリ配下へ置かない。

```bash
bundle install
export PLAY_SERVICE_ACCOUNT_JSON_PATH=/secure/path/play-service-account.json
export ANDROID_AAB_PATH=build/app/outputs/bundle/release/app-release.aab
bundle exec fastlane android validate_play_credentials
bundle exec fastlane android internal
```

AABは既存の署名設定を使って生成し、versionCodeがPlay Console上の既存値より大きいことを確認する。

## ロールバック

Google Playでは使用済みversionCodeを再利用できない。問題があれば内部テストリリースを停止し、修正版をより大きいversionCodeで再アップロードする。署名鍵やサービスアカウント鍵が漏えいした場合は、対象鍵を直ちに無効化・削除し、GitHub Secretを更新する。
