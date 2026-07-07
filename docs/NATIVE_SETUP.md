# ネイティブ設定メモ

このMVPの対象は Android/iOS のみです。Web、Windows、macOS、Linux は v0.2 の対象外です。

`flutter create . --platforms=android,ios` 実行後に必要な設定です。

## Android

### 1. SDKバージョン

`android/app/build.gradle` または `android/app/build.gradle.kts` で以下を確認します。

- minSdkVersion 24
- targetSdkVersion 36
- compileSdkVersion 36

このリポジトリの `tool/configure_android_release.sh` は、Androidリリースビルド時に `minSdk 24`、`targetSdk 36`、`compileSdk 36` に揃えます。
`flutter_local_notifications` は `compileSdk` 35以上を要求するため、36で統一しています。

### 2. flutter_local_notifications の desugaring

スケジュール通知を使うため、Android 側で core library desugaring を有効化します。

Groovy の例:

```gradle
android {
    defaultConfig {
        multiDexEnabled true
    }

    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'
}
```

Kotlin DSL の場合も同等の設定を入れてください。

### 3. 日本語OCR言語パック

`android/app/build.gradle` の dependencies に追加します。

```gradle
dependencies {
    implementation 'com.google.mlkit:text-recognition-japanese:16.0.1'
}
```

### 4. 権限と通知設定

`AndroidManifest.xml` にカメラ権限、Android 13以降の通知権限、広告表示/アプリ内課金に必要なインターネット権限を追加します。

スケジュール通知を端末再起動後にも維持したい場合は、`flutter_local_notifications` の公式 README の AndroidManifest 設定も追加してください。このMVPは `AndroidScheduleMode.inexactAllowWhileIdle` を使っているため、正確なアラーム権限は追加しません。

Android 13以降の通知は実行時許可が必要です。MVPコードでは、初回説明ダイアログでユーザーが「通知を有効にする」を押した後に `flutter_local_notifications` 経由で通知許可を要求します。

## iOS

### 1. iOS Deployment Target

`ios/Podfile` を開き、最低iOSを15.5以上にします。

```ruby
platform :ios, '15.5'
```

ML Kit は32-bitアーキテクチャをサポートしないため、必要に応じて `armv7` を除外します。

### 2. 日本語OCR言語パック

`ios/Podfile` に追加します。

```ruby
pod 'GoogleMLKit/TextRecognitionJapanese', '~> 9.0.0'
```

### 3. Info.plist

`ios/Runner/Info.plist` にカメラ利用理由と写真ライブラリ利用理由を追加します。

## よくある問題

### OCRが英数字しか読めない

日本語言語パックがAndroid/iOS側に追加されていない可能性があります。

### 通知が出ない

- 端末側で通知許可がOFF
- Android 13以降の通知権限未許可
- Androidの省電力制限
- バックグラウンド動作を強く制限する端末設定
- 期限が過去日時
- AndroidManifest のスケジュール通知設定不足
- desugaring 設定不足

### `flutter create` 後にlibが上書きされるか

通常、既存の `lib/` は保持されますが、不安ならZIPをバックアップしてから実行してください。
