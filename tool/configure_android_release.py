#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import re
import xml.etree.ElementTree as ET

DEFAULT_ROOT = Path(__file__).resolve().parent.parent
OCR_DEP_KTS = 'implementation("com.google.mlkit:text-recognition-japanese:16.0.1")'
DESUGAR_DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")'
OLD_DESUGAR_DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
OCR_DEP_GROOVY = "implementation 'com.google.mlkit:text-recognition-japanese:16.0.1'"
DESUGAR_DEP_GROOVY = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'"
OLD_DESUGAR_DEP_GROOVY = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)
REQUIRED_PERMISSIONS = (
    "android.permission.CAMERA",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.INTERNET",
    "android.permission.RECEIVE_BOOT_COMPLETED",
)
EXACT_ALARM_PERMISSION = "android.permission.SCHEDULE_EXACT_ALARM"
SCHEDULED_RECEIVER = "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
BOOT_RECEIVER = "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
BOOT_ACTIONS = (
    "android.intent.action.BOOT_COMPLETED",
    "android.intent.action.MY_PACKAGE_REPLACED",
    "android.intent.action.QUICKBOOT_POWERON",
    "com.htc.intent.action.QUICKBOOT_POWERON",
)
ADMOB_METADATA = "com.google.android.gms.ads.APPLICATION_ID"


def _android(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def replace_or_insert(pattern: str, replacement, text: str) -> str:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        raise RuntimeError(f"Pattern not found: {pattern}")
    return new_text


def transform_kts(text: str) -> str:
    text = re.sub(r"compileSdk\s*=\s*[^\n]+", "compileSdk = flutter.compileSdkVersion", text, count=1)
    text = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", text, count=1)
    text = re.sub(r"targetSdk\s*=\s*[^\n]+", "targetSdk = 36", text, count=1)
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
    text = text.replace(OLD_DESUGAR_DEP_KTS, DESUGAR_DEP_KTS)
    text = re.sub(r'namespace\s*=\s*"[^"]+"', 'namespace = "com.ashita_motsumono"', text, count=1)
    text = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.ashita_motsumono"', text, count=1)
    if "org.jetbrains.kotlin.android" not in text and "kotlin-android" not in text:
        text = replace_or_insert(r'id\("com\.android\.application"\)', 'id("com.android.application")\n    id("org.jetbrains.kotlin.android")', text)
    if "isCoreLibraryDesugaringEnabled" not in text:
        text = replace_or_insert(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", text)
    text = re.sub(r"\n\s*kotlinOptions\s*\{[^}]*\}", "", text)
    if 'manifestPlaceholders["admobAppId"]' not in text:
        text = re.sub(r"(versionName\s*=\s*flutter\.versionName[^\n]*)", lambda m: m.group(1) + '\n        manifestPlaceholders["admobAppId"] = System.getenv("ADMOB_APP_ID") ?: ""', text, count=1)
    if "compilerOptions" not in text:
        text = text.rstrip() + "\n\nkotlin {\n    compilerOptions {\n        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17\n    }\n}\n"
    if "dependencies" not in text:
        text += "\n\ndependencies {\n}\n"
    deps = []
    if DESUGAR_DEP_KTS not in text:
        deps.append(f"    {DESUGAR_DEP_KTS}")
    if OCR_DEP_KTS not in text:
        deps.append(f"    {OCR_DEP_KTS}")
    if deps:
        text = replace_or_insert(r"dependencies\s*\{", "dependencies {\n" + "\n".join(deps), text)
    if "proguard-rules.pro" not in text:
        text = re.sub(r"release\s*\{", 'release {\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', text, count=1)
    return text


def transform_groovy(text: str) -> str:
    text = re.sub(r"compileSdk(?:Version)?\s+[^\n]+", "compileSdkVersion 36", text, count=1)
    text = re.sub(r"minSdk(?:Version)?\s+[^\n]+", "minSdkVersion 24", text, count=1)
    text = re.sub(r"targetSdk(?:Version)?\s+[^\n]+", "targetSdkVersion 36", text, count=1)
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
    text = text.replace(OLD_DESUGAR_DEP_GROOVY, DESUGAR_DEP_GROOVY)
    if "coreLibraryDesugaringEnabled" not in text:
        text = replace_or_insert(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", text)
    if "kotlinOptions" in text:
        text = re.sub(r"jvmTarget\s*=\s*[^\n]+", 'jvmTarget = "17"', text, count=1)
    else:
        text = replace_or_insert(r"compileOptions\s*\{[^}]*\}", lambda m: m.group(0) + '\n\n    kotlinOptions {\n        jvmTarget = "17"\n    }', text)
    if "dependencies" not in text:
        text += "\n\ndependencies {\n}\n"
    deps = []
    if DESUGAR_DEP_GROOVY not in text:
        deps.append(f"    {DESUGAR_DEP_GROOVY}")
    if OCR_DEP_GROOVY not in text:
        deps.append(f"    {OCR_DEP_GROOVY}")
    if deps:
        text = replace_or_insert(r"dependencies\s*\{", "dependencies {\n" + "\n".join(deps), text)
    return text


def ensure_gradle(root: Path) -> None:
    kts = root / "android/app/build.gradle.kts"
    groovy = root / "android/app/build.gradle"
    if kts.exists():
        original = read_text(kts)
        result = transform_kts(original)
        if result != original:
            write_text(kts, result)
    elif groovy.exists():
        original = read_text(groovy)
        result = transform_groovy(original)
        if result != original:
            write_text(groovy, result)
    else:
        raise RuntimeError("No android/app Gradle build file found")


def ensure_proguard(root: Path) -> None:
    path = root / "android/app/proguard-rules.pro"
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
    if not path.exists() or "com.google.mlkit.common.**" not in read_text(path):
        write_text(path, content)


def _parse_manifest(text: str) -> ET.Element:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    return ET.fromstring(text, parser=parser)


def _find_application(root: ET.Element) -> ET.Element:
    app = root.find("application")
    if app is None:
        raise RuntimeError("AndroidManifest.xml has no direct <application> element")
    return app


def _remove_matching_children(parent: ET.Element, tag: str, android_name: str) -> None:
    for child in list(parent):
        if child.tag == tag and child.get(_android("name")) == android_name:
            parent.remove(child)


def _insert_before_application(root: ET.Element, element: ET.Element) -> None:
    for index, child in enumerate(list(root)):
        if child.tag == "application":
            root.insert(index, element)
            return
    raise RuntimeError("AndroidManifest.xml has no direct <application> element")


def _permission(name: str) -> ET.Element:
    return ET.Element("uses-permission", {_android("name"): name})


def _scheduled_receiver() -> ET.Element:
    return ET.Element("receiver", {_android("name"): SCHEDULED_RECEIVER, _android("exported"): "false"})


def _boot_receiver() -> ET.Element:
    receiver = ET.Element("receiver", {_android("name"): BOOT_RECEIVER, _android("exported"): "false"})
    intent_filter = ET.SubElement(receiver, "intent-filter")
    for action in BOOT_ACTIONS:
        ET.SubElement(intent_filter, "action", {_android("name"): action})
    return receiver


def _admob_metadata() -> ET.Element:
    return ET.Element("meta-data", {_android("name"): ADMOB_METADATA, _android("value"): "${admobAppId}"})


def transform_manifest(text: str) -> str:
    had_declaration = text.lstrip().startswith("<?xml")
    root = _parse_manifest(text)
    app = _find_application(root)
    for name in (*REQUIRED_PERMISSIONS, EXACT_ALARM_PERMISSION):
        _remove_matching_children(root, "uses-permission", name)
    for name in REQUIRED_PERMISSIONS:
        _insert_before_application(root, _permission(name))
    _remove_matching_children(app, "receiver", SCHEDULED_RECEIVER)
    _remove_matching_children(app, "receiver", BOOT_RECEIVER)
    _remove_matching_children(app, "meta-data", ADMOB_METADATA)
    app.append(_admob_metadata())
    app.append(_scheduled_receiver())
    app.append(_boot_receiver())
    ET.indent(root, space="    ")
    result = ET.tostring(root, encoding="unicode", short_empty_elements=True)
    if had_declaration:
        result = '<?xml version="1.0" encoding="utf-8"?>\n' + result
    return result.rstrip() + "\n"


def ensure_manifest(root: Path) -> None:
    path = root / "android/app/src/main/AndroidManifest.xml"
    if not path.exists():
        raise RuntimeError("AndroidManifest.xml was not found")
    original = read_text(path)
    result = transform_manifest(original)
    if result != original:
        write_text(path, result)


def configure(root: Path = DEFAULT_ROOT) -> None:
    ensure_gradle(root)
    ensure_proguard(root)
    ensure_manifest(root)


def main() -> None:
    configure()
    print("Android release build configuration applied.")


if __name__ == "__main__":
    main()
