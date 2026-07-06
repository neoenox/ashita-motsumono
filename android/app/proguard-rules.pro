# ML Kit Text Recognition — R8 が参照経路を断ち切ってクラスを削除するのを防ぐ
# MlKitInitProvider (ContentProvider) 起動時の依存性注入失敗を防止するため
# mlkit-common の全クラスも保持する（R8 の -keep はクラスのみ、META-INF は除く）
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_japanese.** { *; }
-keep class com.google.mlkit.common.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.korean.**

# google_mobile_ads / GMA SDK — WorkManager + Room 初期化に必要
# リリースビルドで ProGuard が WorkDatabase や Room 実装クラスを削除するのを防ぐ
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
