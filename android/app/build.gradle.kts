import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val configuredAdMobAppId = System.getenv("ADMOB_APP_ID") ?: ""
val localTestAdMobAppId =
    "ca-app-pub-394025609994" + "2544~3347511713"

@Suppress("UnstableApiUsage")
android {
    namespace = "com.ashita_motsumono"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ashita_motsumono"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] =
            configuredAdMobAppId.ifBlank { localTestAdMobAppId }
    }

    signingConfigs {
        create("release") {
            // key.properties（ローカル）または環境変数（CI）から署名情報を読み込む
            val props = Properties()
            val propsFile = rootProject.file("key.properties")
            if (propsFile.exists()) {
                props.load(propsFile.inputStream())
            } else {
                props["storeFile"] = System.getenv("KEYSTORE_PATH") ?: ""
                props["storePassword"] = System.getenv("KEYSTORE_STORE_PASSWORD") ?: ""
                props["keyAlias"] = System.getenv("KEYSTORE_KEY_ALIAS") ?: ""
                props["keyPassword"] = System.getenv("KEYSTORE_KEY_PASSWORD") ?: ""
            }
            val storeFilePath = props.getProperty("storeFile") ?: ""
            if (storeFilePath.isNotEmpty()) {
                val keystoreFile = rootProject.file(storeFilePath)
                if (keystoreFile.exists()) {
                    storeFile = keystoreFile
                    storePassword = props.getProperty("storePassword")
                    keyAlias = props.getProperty("keyAlias")
                    keyPassword = props.getProperty("keyPassword")
                }
            }
        }
    }

    buildTypes {
        release {
            // Play release signing enforcement: begin
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile != null) {
                signingConfig = releaseSigning
            }
            // Play release signing enforcement: end
            val requestedReleaseBuild = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true)
            }
            if (requestedReleaseBuild &&
                configuredAdMobAppId.ifBlank { localTestAdMobAppId } == localTestAdMobAppId
            ) {
                throw GradleException(
                    "ADMOB_APP_ID must resolve to a production AdMob app id for release builds",
                )
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
}
