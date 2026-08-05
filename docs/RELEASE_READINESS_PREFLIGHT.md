# Release Readiness Preflight

正式署名、タグ、Release、Play Console操作を行う前に、リポジトリ状態とGitHub設定の準備状況だけを検査する安全なpreflightです。

## 目的

次を、ビルド・署名・デプロイ・公開なしで確認します。

- `pubspec.yaml`のRelease version形式
- アプリ内表示versionとの一致
- v0.7.0候補であること
- ストア掲載文と短い説明の存在
- v0.7.0日本語リリースノートの存在
- アイコンとスクリーンショット5枚の存在
- Release手順書とworkflowの存在
- 正式Release workflowが必要な設定名を参照していること
- GitHub Secrets／Repository Variablesの存在有無

Secretsの値は読み出さず、出力には設定名と存在／不足だけを記録します。

## 自動実行

次の変更を含むPull Requestとmaster pushでは、静的preflightだけを実行します。

```text
Release Readiness Preflight / Static release readiness
```

生成artifact:

```text
release-readiness-static-<commit SHA>
```

静的preflightではSecrets／Variablesを参照しません。

## masterでの手動実行

GitHub Actionsから`Release Readiness Preflight`を選び、masterに対して`Run workflow`を実行します。

この場合は次の2jobを実行します。

1. `Static release readiness`
2. `Release configuration presence`

設定確認artifact:

```text
release-readiness-configuration-<commit SHA>
```

不足がある場合はjobを`BLOCKED`にし、次の名前だけをJSONへ記録します。

### Secrets

- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`
- `GEMINI_PROXY_URL`

### Repository Variables

- `ANDROID_UPLOAD_CERT_SHA256`
- `IAP_REMOVE_ADS_PRODUCT_ID`
- `IAP_AI_ACCESS_PRODUCT_ID`

## ローカル静的確認

```powershell
python tool/release_readiness_preflight.py `
  --root . `
  --expected-version-prefix 0.7.0+ `
  --output build/release-readiness/static-preflight.json
```

Python単体テスト:

```powershell
python -m unittest tool/test_release_readiness_preflight.py
```

通常の`flutter test`からも同じPythonテストを実行します。

## 判定後の順序

preflightがPASSしても正式Releaseは開始しません。Release gateの順序は次のままです。

```text
Issue #60 → Issue #98 → Issue #59 → Issue #94
```

1. Issue #60: Normal／Reboot／install-r通知証跡
2. Issue #98: Play App Signingとアップロード証明書照合
3. Issue #59: 正式署名済みAPK／AAB生成
4. Issue #94: Play提出、内部テスト、審査、公開

preflightは外部受入や正式Releaseの代替ではありません。
