#!/usr/bin/env python3
"""Apply Android release build configuration for ashita_motsumono.

Modifies:
- android/app/build.gradle.kts  — SDK versions, desugaring, ML Kit deps, ProGuard
- android/app/src/main/AndroidManifest.xml — permissions, receivers, AdMob metadata
- android/app/proguard-rules.pro            — ML Kit keep rules (if missing)

Idempotent: safe to run multiple times. Uses xml.etree.ElementTree for manifest edits.
"""

from pathlib import Path
import re
import xml.etree.ElementTree as ET
from xml.dom import minidom
import io

ROOT = Path.cwd()
APP_KTS = ROOT / "android/app/build.gradle.kts"
APP_GROOVY = ROOT / "android/app/build.gradle"
MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"
PROGUARD = ROOT / "android/app/proguard-rules.pro"

OCR_DEP_KTS = 'implementation("com.google.mlkit:text-recognition-japanese:16.0.1")'
DESUGAR_DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")'
OLD_DESUGAR_DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'

# ── helpers ──────────────────────────────────────────────────────────

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def replace_or_insert(pattern: str, replacement: str, text: str) -> str:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        raise RuntimeError(f"Pattern not found: {pattern}")
    return new_text


# ── Gradle KTS ───────────────────────────────────────────────────────

def ensure_kts():
    text = read_text(APP_KTS)
    text = re.sub(r"compileSdk\s*=\s*[^\n]+", 'compileSdk = flutter.compileSdkVersion', text, count=1)
    text = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", text, count=1)
    text = re.sub(r"targetSdk\s*=\s*[^\n]+", "targetSdk = 36", text, count=1)
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
    text = text.replace(OLD_DESUGAR_DEP_KTS, DESUGAR_DEP_KTS)
    text = re.sub(r'namespace\s*=\s*"[^"]+"', 'namespace = "com.ashita_motsumono"', text, count=1)
    text = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.ashita_motsumono"', text, count=1)

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

    write_text(APP_KTS, text)


# ── Gradle Groovy ────────────────────────────────────────────────────

def ensure_groovy():
    text = read_text(APP_GROOVY)
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

    write_text(APP_GROOVY, text)


# ── ProGuard ─────────────────────────────────────────────────────────

def ensure_proguard():
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
    if not PROGUARD.exists():
        write_text(PROGUARD, content)
    else:
        existing = read_text(PROGUARD)
        if 'com.google.mlkit.common.**' not in existing:
            write_text(PROGUARD, content)


# ── AndroidManifest.xml (hybrid: ElementTree detection + text insertion) ─

_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", _NS)


def _ns(name: str) -> str:
    return f"{{{_NS}}}{name}"


def _has_element(root: ET.Element, tag: str, attrib: str, value: str) -> bool:
    """Check if <tag android:attrib="value" /> exists anywhere under root."""
    for child in root.iter(tag):
        if child.get(_ns(attrib)) == value:
            return True
    return False


def _detect_missing(text: str):
    """Analyze manifest XML and return (missing_perms, missing_receivers, admob_missing)."""
    root = ET.fromstring(text)
    required_permissions = [
        'android.permission.CAMERA',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.INTERNET',
        'android.permission.RECEIVE_BOOT_COMPLETED',
    ]
    missing_perms = [p for p in required_permissions
                     if not _has_element(root, "uses-permission", "name", p)]
    missing_receivers = []
    for rn in ["com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
               "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"]:
        if not _has_element(root, "receiver", "name", rn):
            missing_receivers.append(rn)
    admob_missing = not _has_element(root, "meta-data", "name",
                                     "com.google.android.gms.ads.APPLICATION_ID")
    return missing_perms, missing_receivers, admob_missing


def transform_manifest(text: str) -> str:
    """Pure function: apply manifest transformations. Idempotent."""
    # Strip trailing whitespace from every line first
    text = "\n".join(line.rstrip() for line in text.splitlines()) + "\n"

    missing_perms, missing_receivers, admob_missing = _detect_missing(text)
    if not (missing_perms or missing_receivers or admob_missing):
        return text

    if missing_perms:
        insertion = "\n" + "\n".join(
            f'    <uses-permission android:name="{p}" />' for p in missing_perms
        ) + "\n"
        text = text.replace(">\n    <application", ">" + insertion + "    <application", 1)

    closing_parts = []
    if missing_receivers:
        for r_name in missing_receivers:
            if "BootReceiver" in r_name:
                closing_parts.append(
                    '        <receiver\n'
                    f'            android:name="{r_name}"\n'
                    '            android:exported="true">\n'
                    '            <intent-filter>\n'
                    '                <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
                    '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
                    '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
                    '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />\n'
                    '            </intent-filter>\n'
                    '        </receiver>'
                )
            else:
                closing_parts.append(
                    '        <receiver\n'
                    f'            android:name="{r_name}"\n'
                    '            android:exported="false" />'
                )
    if admob_missing:
        closing_parts.append(
            '        <meta-data\n'
            '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
            '            android:value="${admobAppId}"/>'
        )

    if closing_parts:
        # Replace leading whitespace + </application> to avoid trailing whitespace
        import re as _re
        insertion = "\n".join(closing_parts) + "\n    "
        text = _re.sub(r"[ \t]*\n[ \t]*</application>", "\n" + insertion + "</application>", text, count=1)

    # Strip trailing whitespace from every line
    text = "\n".join(line.rstrip() for line in text.splitlines()) + "\n"
    return text


def ensure_manifest():
    text = read_text(MANIFEST)
    result = transform_manifest(text)
    if result != text:
        write_text(MANIFEST, result)


# ── main ─────────────────────────────────────────────────────────────

def main():
    if APP_KTS.exists():
        ensure_kts()
    elif APP_GROOVY.exists():
        ensure_groovy()
    else:
        raise RuntimeError("No android/app Gradle build file found")

    ensure_proguard()

    if not MANIFEST.exists():
        raise RuntimeError("AndroidManifest.xml was not found")
    ensure_manifest()

    print("Android release build configuration applied.")


if __name__ == "__main__":
    main()
