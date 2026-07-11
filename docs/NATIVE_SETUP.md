# ネイティブ設定

このアプリは Flutter で実装されています。Androidのネイティブ設定は、リポジトリ直下から設定スクリプトを実行して適用します。

## Android

### 1. SDKバージョン

- minSdkVersion 24
- targetSdkVersion 36
- compileSdkVersion 36

このリポジトリの `tool/configure_android_release.py`（または `tool/configure_android_release.sh`）は、Androidリリースビルド時に `minSdk 24`、`targetSdk 36`、`compileSdk 36` に揃えます。
`flutter_local_notifications` は `compileSdk` 35以上を要求するため、36で統一しています。

### 2. flutter_local_notifications の desugaring

`android/app/build.gradle.kts` の `compileOptions` でcore library desugaringを有効にし、次の依存関係を追加します。

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

Groovy形式の `build.gradle` も同じスクリプトで設定できます。

### 3. AndroidネイティブOCR

`MainActivity.kt` のMethodChannelからGoogle ML Kit日本語テキスト認識を呼び出します。

```kotlin
dependencies {
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
}
```

Groovy形式の場合:

```groovy
dependencies {
    implementation 'com.google.mlkit:text-recognition-japanese:16.0.1'
}
```

### 4. 権限と通知設定

`AndroidManifest.xml` にカメラ権限、Android 13以降の通知権限、広告表示/アプリ内課金に必要なインターネット権限、ブート完了受信権限を追加します。

スケジュール通知を端末再起動後にも維持するため、`flutter_local_notifications` の `ScheduledNotificationReceiver` と `ScheduledNotificationBootReceiver` を追加します。このMVPは `AndroidScheduleMode.inexactAllowWhileIdle` を使っているため、正確なアラーム権限（`SCHEDULE_EXACT_ALARM`）は追加しません。

**これらの設定は `tool/configure_android_release.py` で構造的かつ冪等に適用されます。** 既存の不足・重複・誤ったexported値・不足したintent actionを正規化し、無関係なActivity、Service、Provider、Receiver、Metadata、Queries、コメントは保持します。

実行方法:

- **Windows**: `python tool/configure_android_release.py`
- **Linux/macOS / CI**: `bash tool/configure_android_release.sh`
- **クロスプラットフォーム（直接）**: `python tool/configure_android_release.py`

適用される設定:

- 権限:
  - `android.permission.CAMERA`
  - `android.permission.POST_NOTIFICATIONS`
  - `android.permission.INTERNET`
  - `android.permission.RECEIVE_BOOT_COMPLETED`
- Receiver:
  - `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`（exported=false）
  - `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver`（exported=false）
    - intent-filter: `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, `com.htc.intent.action.QUICKBOOT_POWERON`
- AdMobメタデータ: `com.google.android.gms.ads.APPLICATION_ID`（プレースホルダ `${admobAppId}`）

検証:

```bash
python tool/verify_android_manifest.py
```

検証器は本番Manifestに加え、最小構成、既存権限、Activity/Metadata保持、片方のReceiverのみ、正常構成、不正XML、日本語UTF-8、誤ったexported値、不足action、重複Receiver、重複action、無関係Receiver保持、Groovy形式、リポジトリ外のカレントディレクトリからの実行を確認します。

Android 13以降の通知は実行時許可が必要です。MVPコードでは、初回説明ダイアログでユーザーが「通知を有効にする」を押した後に `flutter_local_notifications` 経由で通知許可を要求します。

## iOS

### 1. iOS Deployment Target

`ios/Podfile` を開き、最低iOSを15.5以上にします。

```ruby
platform :ios, '15.5'
```

### 2. 権限説明

`ios/Runner/Info.plist` にカメラと写真アクセスの用途説明を追加します。

```xml
<key>NSCameraUsageDescription</key>
<string>配布物を撮影して持ち物を登録するために使用します。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>配布物の画像を選択して持ち物を登録するために使用します。</string>
```

通知権限はアプリ内の説明後に要求します。
