# ネイティブ設定メモ

`flutter create . --platforms=android,ios` 実行後に必要な設定です。

## Android

### 1. SDKバージョン

`android/app/build.gradle` または `android/app/build.gradle.kts` で以下を確認します。

```gradle
minSdkVersion 24
targetSdkVersion 35
compileSdkVersion 35
```

ML Kit Text RecognitionのFlutterプラグインはAndroidで minSdkVersion 24、target/compile SDK 35を案内しています。

### 2. 日本語OCR言語パック

`android/app/build.gradle` の dependencies に追加します。

```gradle
dependencies {
    implementation 'com.google.mlkit:text-recognition-japanese:16.0.1'
}
```

### 3. 権限

`android/app/src/main/AndroidManifest.xml` に必要に応じて追加します。

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Android 13以降の通知は実行時許可が必要です。MVPコードでは `flutter_local_notifications` 経由で通知許可を要求しています。

## iOS

### 1. iOS Deployment Target

`ios/Podfile` を開き、最低iOSを15.5以上にします。

```ruby
platform :ios, '15.5'
```

### 2. 日本語OCR言語パック

`ios/Podfile` に追加します。

```ruby
pod 'GoogleMLKit/TextRecognitionJapanese', '~> 9.0.0'
```

### 3. Info.plist

`ios/Runner/Info.plist` に追加します。

```xml
<key>NSCameraUsageDescription</key>
<string>プリントを撮影して持ち物・提出物を読み取るためにカメラを使用します。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>スクリーンショットやプリント画像を選択するために写真ライブラリを使用します。</string>
```

## よくある問題

### OCRが英数字しか読めない

日本語言語パックがAndroid/iOS側に追加されていない可能性があります。

### 通知が出ない

- 端末側で通知許可がOFF
- Android 13以降の通知権限未許可
- Androidの省電力制限
- 期限が過去日時

### `flutter create` 後にlibが上書きされるか

通常、既存の `lib/` は保持されますが、不安ならZIPをバックアップしてから実行してください。
