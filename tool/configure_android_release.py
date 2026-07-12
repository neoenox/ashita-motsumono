#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import xml.etree.ElementTree as ET

DEFAULT_ROOT = Path(__file__).resolve().parent.parent
OCR_DEP_KTS = 'implementation("com.google.mlkit:text-recognition-japanese:16.0.1")'
DESUGAR_DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")'
OCR_DEP_GROOVY = "implementation 'com.google.mlkit:text-recognition-japanese:16.0.1'"
DESUGAR_DEP_GROOVY = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'"
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
PROGUARD_RULES = (
    "-keep class com.google.mlkit.vision.text.** { *; }",
    "-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }",
    "-keep class com.google.android.gms.internal.mlkit_vision_text_japanese.** { *; }",
    "-keep class com.google.mlkit.common.** { *; }",
    "-dontwarn com.google.mlkit.vision.text.chinese.**",
    "-dontwarn com.google.mlkit.vision.text.devanagari.**",
    "-dontwarn com.google.mlkit.vision.text.korean.**",
    "-keep class androidx.work.** { *; }",
    "-keep class * extends androidx.room.RoomDatabase { *; }",
    "-keep @androidx.room.Database class * { *; }",
)
KTS_DESUGAR_PATTERN = re.compile(
    r'''^(?P<indent>[ \t]*)coreLibraryDesugaring\s*\(\s*["']'''
    r'''com\.android\.tools:desugar_jdk_libs:[^"']+["']\s*\)'''
    r'''(?P<comment>[ \t]*//.*)?$''',
    re.MULTILINE,
)
GROOVY_DESUGAR_PATTERN = re.compile(
    r'''^(?P<indent>[ \t]*)coreLibraryDesugaring\s+["']'''
    r'''com\.android\.tools:desugar_jdk_libs:[^"']+["']'''
    r'''(?P<comment>[ \t]*//.*)?$''',
    re.MULTILINE,
)


def _android(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as output:
        output.write(text)


def replace_or_insert(pattern: str, replacement, text: str) -> str:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        raise RuntimeError(f"Pattern not found: {pattern}")
    return new_text


def _normalize_dependency_lines(
    text: str,
    pattern: re.Pattern[str],
    canonical: str,
) -> tuple[str, bool]:
    found = False

    def replacement(match: re.Match[str]) -> str:
        nonlocal found
        if found:
            return ""
        found = True
        comment = match.group("comment") or ""
        return f"{match.group('indent')}{canonical}{comment}"

    return pattern.sub(replacement, text), found


def _matching_brace(text: str, open_index: int) -> int:
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    index = open_index

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""

        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue

        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                index += 2
            else:
                index += 1
            continue

        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue

        if char == "/" and next_char == "/":
            line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            index += 2
            continue
        if char in ('"', "'"):
            quote = char
            index += 1
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1

    raise RuntimeError("Unbalanced Gradle braces")


def _remove_named_blocks(text: str, block_name: str) -> str:
    pattern = re.compile(rf"(?m)^[ \t]*{re.escape(block_name)}\s*\{{")
    while True:
        match = pattern.search(text)
        if match is None:
            return text
        open_index = text.find("{", match.start(), match.end())
        close_index = _matching_brace(text, open_index)
        end = close_index + 1
        if end < len(text) and text[end] == "\n":
            end += 1
        text = text[: match.start()] + text[end:]


def _append_after_named_block(text: str, block_name: str, addition: str) -> str:
    match = re.search(rf"(?m)^[ \t]*{re.escape(block_name)}\s*\{{", text)
    if match is None:
        raise RuntimeError(f"Gradle block not found: {block_name}")
    open_index = text.find("{", match.start(), match.end())
    close_index = _matching_brace(text, open_index)
    return text[: close_index + 1] + addition + text[close_index + 1 :]


def transform_kts(text: str) -> str:
    text = re.sub(
        r"compileSdk\s*=\s*[^\n]+",
        "compileSdk = flutter.compileSdkVersion",
        text,
        count=1,
    )
    text = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", text, count=1)
    text = re.sub(r"targetSdk\s*=\s*[^\n]+", "targetSdk = 36", text, count=1)
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
    text, had_desugar = _normalize_dependency_lines(
        text,
        KTS_DESUGAR_PATTERN,
        DESUGAR_DEP_KTS,
    )
    text = re.sub(
        r'namespace\s*=\s*"[^"]+"',
        'namespace = "com.ashita_motsumono"',
        text,
        count=1,
    )
    text = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "com.ashita_motsumono"',
        text,
        count=1,
    )
    if "org.jetbrains.kotlin.android" not in text and "kotlin-android" not in text:
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
    text = _remove_named_blocks(text, "kotlinOptions")
    if 'manifestPlaceholders["admobAppId"]' not in text:
        text = re.sub(
            r"(versionName\s*=\s*flutter\.versionName[^\n]*)",
            lambda match: match.group(1)
            + '\n        manifestPlaceholders["admobAppId"] = '
            'System.getenv("ADMOB_APP_ID") ?: ""',
            text,
            count=1,
        )
    if "compilerOptions" not in text:
        text = (
            text.rstrip()
            + "\n\nkotlin {\n"
            "    compilerOptions {\n"
            "        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17\n"
            "    }\n"
            "}\n"
        )
    if "dependencies" not in text:
        text += "\n\ndependencies {\n}\n"
    dependencies = []
    if not had_desugar:
        dependencies.append(f"    {DESUGAR_DEP_KTS}")
    if OCR_DEP_KTS not in text:
        dependencies.append(f"    {OCR_DEP_KTS}")
    if dependencies:
        text = replace_or_insert(
            r"dependencies\s*\{",
            "dependencies {\n" + "\n".join(dependencies),
            text,
        )
    if "proguard-rules.pro" not in text:
        text = re.sub(
            r"release\s*\{",
            'release {\n'
            '            proguardFiles('
            'getDefaultProguardFile("proguard-android-optimize.txt"), '
            '"proguard-rules.pro")',
            text,
            count=1,
        )
    return text


def transform_groovy(text: str) -> str:
    text = re.sub(
        r"compileSdk(?:Version)?\s+[^\n]+",
        "compileSdkVersion 36",
        text,
        count=1,
    )
    text = re.sub(
        r"minSdk(?:Version)?\s+[^\n]+",
        "minSdkVersion 24",
        text,
        count=1,
    )
    text = re.sub(
        r"targetSdk(?:Version)?\s+[^\n]+",
        "targetSdkVersion 36",
        text,
        count=1,
    )
    text = text.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
    text, had_desugar = _normalize_dependency_lines(
        text,
        GROOVY_DESUGAR_PATTERN,
        DESUGAR_DEP_GROOVY,
    )
    if "coreLibraryDesugaringEnabled" not in text:
        text = replace_or_insert(
            r"compileOptions\s*\{",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            text,
        )
    if "kotlinOptions" in text:
        text = re.sub(r"jvmTarget\s*=\s*[^\n]+", 'jvmTarget = "17"', text, count=1)
    else:
        text = _append_after_named_block(
            text,
            "compileOptions",
            '\n\n    kotlinOptions {\n        jvmTarget = "17"\n    }',
        )
    if "dependencies" not in text:
        text += "\n\ndependencies {\n}\n"
    dependencies = []
    if not had_desugar:
        dependencies.append(f"    {DESUGAR_DEP_GROOVY}")
    if OCR_DEP_GROOVY not in text:
        dependencies.append(f"    {OCR_DEP_GROOVY}")
    if dependencies:
        text = replace_or_insert(
            r"dependencies\s*\{",
            "dependencies {\n" + "\n".join(dependencies),
            text,
        )
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
    original = read_text(path) if path.exists() else ""
    existing_lines = {line.strip() for line in original.splitlines()}
    missing = [rule for rule in PROGUARD_RULES if rule not in existing_lines]
    if not missing:
        return

    addition = (
        "# Android release configuration: required ML Kit / GMA keep rules\n"
        + "\n".join(missing)
        + "\n"
    )
    result = original.rstrip()
    if result:
        result += "\n\n"
    result += addition
    write_text(path, result)


def _parse_manifest(text: str) -> ET.Element:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    return ET.fromstring(text, parser=parser)


def _find_application(root: ET.Element) -> ET.Element:
    app = root.find("application")
    if app is None:
        raise RuntimeError("AndroidManifest.xml has no direct <application> element")
    return app


def _remove_matching_children(
    parent: ET.Element,
    tag: str,
    android_name: str,
) -> None:
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
    return ET.Element(
        "receiver",
        {
            _android("name"): SCHEDULED_RECEIVER,
            _android("exported"): "false",
        },
    )


def _boot_receiver() -> ET.Element:
    receiver = ET.Element(
        "receiver",
        {
            _android("name"): BOOT_RECEIVER,
            _android("exported"): "false",
        },
    )
    intent_filter = ET.SubElement(receiver, "intent-filter")
    for action in BOOT_ACTIONS:
        ET.SubElement(intent_filter, "action", {_android("name"): action})
    return receiver


def _admob_metadata(attributes: dict[str, str] | None = None) -> ET.Element:
    attrs = dict(attributes or {})
    attrs[_android("name")] = ADMOB_METADATA
    if _android("value") not in attrs and _android("resource") not in attrs:
        attrs[_android("value")] = "${admobAppId}"
    return ET.Element("meta-data", attrs)


def transform_manifest(text: str) -> str:
    had_declaration = text.lstrip().startswith("<?xml")
    root = _parse_manifest(text)
    app = _find_application(root)

    for name in (*REQUIRED_PERMISSIONS, EXACT_ALARM_PERMISSION):
        _remove_matching_children(root, "uses-permission", name)
    for name in REQUIRED_PERMISSIONS:
        _insert_before_application(root, _permission(name))

    existing_admob: dict[str, str] | None = None
    for child in list(app):
        if child.tag == "meta-data" and child.get(_android("name")) == ADMOB_METADATA:
            if existing_admob is None:
                existing_admob = dict(child.attrib)

    _remove_matching_children(app, "receiver", SCHEDULED_RECEIVER)
    _remove_matching_children(app, "receiver", BOOT_RECEIVER)
    _remove_matching_children(app, "meta-data", ADMOB_METADATA)

    app.append(_admob_metadata(existing_admob))
    app.append(_scheduled_receiver())
    app.append(_boot_receiver())

    ET.indent(root, space="    ")
    result = ET.tostring(
        root,
        encoding="unicode",
        short_empty_elements=True,
    )
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
