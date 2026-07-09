#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d android ]]; then
  echo "android/ was not found. Run tool/create_platforms.sh first." >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

root = Path.cwd()
app_kts = root / "android/app/build.gradle.kts"
app_groovy = root / "android/app/build.gradle"
manifest = root / "android/app/src/main/AndroidManifest.xml"

OCR_DEP_KTS = 'implementation("com.google.mlkit:text-recognition-japanese:16.0.1")'
DESUGAR_DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")'
OLD_DESUGAR_DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
OCR_DEP_GROOVY = "implementation 'com.google.mlkit:text-recognition-japanese:16.0.1'"
DESUGAR_DEP_GROOVY = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'"
OLD_DESUGAR_DEP_GROOVY = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"


def replace_or_insert(pattern: str, replacement: str, text: str) -> str:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        raise RuntimeError(f"Pattern not found: {pattern}")
    return new_text


def ensure_kts():
    text = app_kts.read_text()
    text = re.sub(r"compileSdk\s*=\s*[^\n]+", 'compileSdk = flutter.compileSdkVersion', text, count=1)
    text = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", text, count=1)
    text = re.sub(r"targetSdk\s*=\s*[^\n]+", "targetSdk = 36", text, count=1)
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
    text = text.replace(OLD_DESUGAR_DEP_KTS, DESUGAR_DEP_KTS)
    text = re.sub(
        r'namespace\s*=\s*"[^"]+"',
        'namespace = "com.ashita_motsumono"',
        text, count=1,
    )
    text = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "com.ashita_motsumono"',
        text, count=1,
    )

    if 'org.jetbrains.kotlin.android' not in text and 'kotlin-android' not in text:
        text = replace_or_insert(
            r'id\("com\.android\.application"\)',
            'id("com.android.application")\n    id("org.jetbrains.kotlin.android")',
            text,
        )

    if "isCoreLibraryDesugaringEnabled" not in text:
        text = replace_or_insert(
            r"compileOptions\s*\{",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            text,
        )

    text = re.sub(r'\n\s*kotlinOptions\s*\{[^}]*\}', '', text)

    if 'manifestPlaceholders["admobAppId"]' not in text:
        text = re.sub(
            r'(versionName\s*=\s*flutter\.versionName[^\n]*)',
            lambda m: m.group(1)
            + '\n        manifestPlaceholders["admobAppId"] ='
            + ' System.getenv("ADMOB_APP_ID")'
            + ' ?: ""',
            text, count=1,
        )

    if 'compilerOptions' not in text:
        text = text.rstrip() + '\n\nkotlin {\n    compilerOptions {\n        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17\n    }\n}\n'

    if "dependencies" not in text:
        text += "\n\ndependencies {\n}\n"
    deps_to_add = []
    if DESUGAR_DEP_KTS not in text:
        deps_to_add.append(f"    {DESUGAR_DEP_KTS}")
    if OCR_DEP_KTS not in text:
        deps_to_add.append(f"    {OCR_DEP_KTS}")
    if deps_to_add:
        text = replace_or_insert(
            r"dependencies\s*\{",
            "dependencies {\n" + "\n".join(deps_to_add),
            text,
        )

    if 'proguard-rules.pro' not in text:
        text = re.sub(
            r'release\s*\{',
            'release {\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
            text,
            count=1,
        )

    app_kts.write_text(text)


def ensure_groovy():
    text = app_groovy.read_text()
    text = re.sub(r"compileSdk(?:Version)?\s+[^\n]+", "compileSdkVersion 36", text, count=1)
    text = re.sub(r"minSdk(?:Version)?\s+[^\n]+", "minSdkVersion 24", text, count=1)
    text = re.sub(r"targetSdk(?:Version)?\s+[^\n]+", "targetSdkVersion 36", text, count=1)
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
    text = text.replace(OLD_DESUGAR_DEP_GROOVY, DESUGAR_DEP_GROOVY)

    if "coreLibraryDesugaringEnabled" not in text:
        text = replace_or_insert(
            r"compileOptions\s*\{",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            text,
        )

    if "kotlinOptions" in text:
        text = re.sub(r"jvmTarget\s*=\s*[^\n]+", 'jvmTarget = "17"', text, count=1)
    else:
        text = replace_or_insert(
            r"compileOptions\s*\{[^}]*\}",
            lambda m: m.group(0) + '\n\n    kotlinOptions {\n        jvmTarget = "17"\n    }',
            text,
        )

    if "dependencies" not in text:
        text += "\n\ndependencies {\n}\n"
    deps_to_add = []
    if DESUGAR_DEP_GROOVY not in text:
        deps_to_add.append(f"    {DESUGAR_DEP_GROOVY}")
    if OCR_DEP_GROOVY not in text:
        deps_to_add.append(f"    {OCR_DEP_GROOVY}")
    if deps_to_add:
        text = replace_or_insert(
            r"dependencies\s*\{",
            "dependencies {\n" + "\n".join(deps_to_add),
            text,
        )

    app_groovy.write_text(text)


def ensure_proguard():
    rules = root / "android/app/proguard-rules.pro"
    content = (
        "# ML Kit Text Recognition - R8 keep rules for Japanese OCR\n"
        "# MlKitInitProvider (ContentProvider) starts during app launch;\n"
        "# R8 strips mlkit-common DI classes without these rules.\n"
        "-keep class com.google.mlkit.vision.text.** { *; }\n"
        "-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }\n"
        "-keep class com.google.android.gms.internal.mlkit_vision_text_japanese.** { *; }\n"
        "-keep class com.google.mlkit.common.** { *; }\n"
        "-dontwarn com.google.mlkit.vision.text.chinese.**\n"
        "-dontwarn com.google.mlkit.vision.text.devanagari.**\n"
        "-dontwarn com.google.mlkit.vision.text.korean.**\n"
        "# google_mobile_ads / GMA SDK - WorkManager + Room initialization\n"
        "-keep class androidx.work.** { *; }\n"
        "-keep class * extends androidx.room.RoomDatabase { *; }\n"
        "-keep @androidx.room.Database class * { *; }\n"
    )
    if not rules.exists():
        rules.write_text(content)
    else:
        existing = rules.read_text()
        if 'com.google.mlkit.common.**' not in existing:
            rules.write_text(content)


def ensure_manifest():
    text = manifest.read_text()
    permissions = [
        '<uses-permission android:name="android.permission.CAMERA" />',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
        '<uses-permission android:name="android.permission.INTERNET" />',
    ]
    missing = [p for p in permissions if p not in text]
    if missing:
        insertion = "\n" + "\n".join(f"    {p}" for p in missing) + "\n"
        text = text.replace(">\n    <application", ">" + insertion + "    <application", 1)
    admob_metadata = (
        '<meta-data\n'
        '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
        '            android:value="${admobAppId}"/>'
    )
    if admob_metadata not in text:
        text = text.replace("</application>", f"        {admob_metadata}\n    </application>", 1)
    manifest.write_text(text)


if app_kts.exists():
    ensure_kts()
elif app_groovy.exists():
    ensure_groovy()
else:
    raise RuntimeError("No android/app Gradle build file found")

ensure_proguard()

if not manifest.exists():
    raise RuntimeError("AndroidManifest.xml was not found")
ensure_manifest()
PY

echo "Android release build configuration applied."
