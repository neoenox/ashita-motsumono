#!/usr/bin/env python3
"""Verify the Android Manifest transformer and release configuration."""

from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tool"))

from configure_android_release import (  # noqa: E402
    ADMOB_METADATA,
    ANDROID_NS,
    BOOT_ACTIONS,
    BOOT_RECEIVER,
    DESUGAR_DEP_GROOVY,
    DESUGAR_DEP_KTS,
    EXACT_ALARM_PERMISSION,
    PROGUARD_RULES,
    REQUIRED_PERMISSIONS,
    SCHEDULED_RECEIVER,
    ensure_proguard,
    transform_groovy,
    transform_kts,
    transform_manifest,
)

MANIFEST = REPO_ROOT / "android/app/src/main/AndroidManifest.xml"
FIXTURES_DIR = REPO_ROOT / "test/fixtures"


def _android(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def _parse(text: str) -> ET.Element:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    return ET.fromstring(text, parser=parser)


def _direct_children(
    parent: ET.Element,
    tag: str,
    name: str,
) -> list[ET.Element]:
    return [
        child
        for child in list(parent)
        if child.tag == tag and child.get(_android("name")) == name
    ]


def validate_manifest(
    text: str,
    expected_admob_value: str = "${admobAppId}",
) -> list[str]:
    errors: list[str] = []
    try:
        root = _parse(text)
    except ET.ParseError as error:
        return [f"malformed XML: {error}"]

    applications = [child for child in list(root) if child.tag == "application"]
    if len(applications) != 1:
        return [f"application count={len(applications)} (expected 1)"]
    application = applications[0]

    for permission in REQUIRED_PERMISSIONS:
        count = len(_direct_children(root, "uses-permission", permission))
        if count != 1:
            errors.append(f"{permission}: count={count} (expected 1)")

    exact_count = len(
        _direct_children(
            root,
            "uses-permission",
            EXACT_ALARM_PERMISSION,
        )
    )
    if exact_count != 0:
        errors.append(
            f"{EXACT_ALARM_PERMISSION}: count={exact_count} (expected 0)"
        )

    scheduled = _direct_children(
        application,
        "receiver",
        SCHEDULED_RECEIVER,
    )
    if len(scheduled) != 1:
        errors.append(
            "ScheduledNotificationReceiver "
            f"count={len(scheduled)} (expected 1)"
        )
    elif scheduled[0].get(_android("exported")) != "false":
        errors.append("ScheduledNotificationReceiver exported must be false")

    boot = _direct_children(application, "receiver", BOOT_RECEIVER)
    if len(boot) != 1:
        errors.append(
            "ScheduledNotificationBootReceiver "
            f"count={len(boot)} (expected 1)"
        )
    else:
        boot_receiver = boot[0]
        if boot_receiver.get(_android("exported")) != "false":
            errors.append(
                "ScheduledNotificationBootReceiver exported must be false"
            )
        filters = [
            child
            for child in list(boot_receiver)
            if child.tag == "intent-filter"
        ]
        if len(filters) != 1:
            errors.append(
                f"BootReceiver intent-filter count={len(filters)} (expected 1)"
            )
        for action_name in BOOT_ACTIONS:
            count = sum(
                1
                for intent_filter in filters
                for child in list(intent_filter)
                if child.tag == "action"
                and child.get(_android("name")) == action_name
            )
            if count != 1:
                errors.append(
                    f"BootReceiver action {action_name}: "
                    f"count={count} (expected 1)"
                )

    admob = _direct_children(application, "meta-data", ADMOB_METADATA)
    if len(admob) != 1:
        errors.append(f"AdMob metadata count={len(admob)} (expected 1)")
    else:
        value = admob[0].get(_android("value"))
        if value != expected_admob_value:
            errors.append(
                "AdMob metadata value "
                f"{value!r} (expected {expected_admob_value!r})"
            )

    return errors


def check_production_manifest() -> bool:
    print("=== Production Manifest ===")
    if not MANIFEST.exists():
        print(f"FAIL: {MANIFEST} does not exist")
        return False
    errors = validate_manifest(MANIFEST.read_text(encoding="utf-8"))
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return False
    print("PASS: production Manifest is structurally valid")
    return True


def run_fixture_tests() -> bool:
    print("\n=== Manifest Fixtures ===")
    fixture_files = sorted(FIXTURES_DIR.glob("*.xml"))
    if not fixture_files:
        print("FAIL: no XML fixtures found")
        return False

    all_ok = True
    for fixture in fixture_files:
        text = fixture.read_text(encoding="utf-8")
        if fixture.name == "006_malformed.xml":
            try:
                transform_manifest(text)
            except ET.ParseError:
                print(f"PASS: {fixture.name} rejected")
            else:
                print(f"FAIL: {fixture.name} was accepted")
                all_ok = False
            continue

        try:
            first = transform_manifest(text)
            second = transform_manifest(first)
        except Exception as error:
            print(f"FAIL: {fixture.name}: {error}")
            all_ok = False
            continue

        errors = validate_manifest(first)
        if first != second:
            errors.append("second transformation differs from first")
        if (
            fixture.name == "007_japanese_utf8.xml"
            and "日本語のアプリ名" not in first
        ):
            errors.append("Japanese UTF-8 label was not preserved")
        if fixture.name == "012_unrelated_receiver.xml":
            root = _parse(first)
            app = root.find("application")
            custom_count = (
                0
                if app is None
                else len(
                    _direct_children(
                        app,
                        "receiver",
                        "com.example.CustomReceiver",
                    )
                )
            )
            if custom_count != 1:
                errors.append(
                    f"unrelated receiver count={custom_count} (expected 1)"
                )
            if "preserve this comment" not in first:
                errors.append("unrelated receiver comment was not preserved")

        if errors:
            all_ok = False
            print(f"FAIL: {fixture.name}")
            for error in errors:
                print(f"  - {error}")
        else:
            digest = hashlib.sha256(first.encode("utf-8")).hexdigest()
            print(
                f"PASS: {fixture.name} "
                f"idempotent sha256={digest}"
            )
    return all_ok


def run_admob_preservation_test() -> bool:
    print("\n=== AdMob Metadata Preservation ===")
    real_app_id = "ca-app-pub-1234567890123456~1234567890"
    sample = f"""<manifest xmlns:android="{ANDROID_NS}">
    <application android:label="AdMob preservation">
        <meta-data
            android:name="{ADMOB_METADATA}"
            android:value="{real_app_id}" />
        <meta-data
            android:name="{ADMOB_METADATA}"
            android:value="${{admobAppId}}" />
    </application>
</manifest>
"""
    first = transform_manifest(sample)
    second = transform_manifest(first)
    errors = validate_manifest(first, expected_admob_value=real_app_id)
    if first != second:
        errors.append("second transformation differs from first")
    if first.count(real_app_id) != 1:
        errors.append(
            f"real AdMob app id count={first.count(real_app_id)} (expected 1)"
        )
    if "${admobAppId}" in first:
        errors.append("fallback placeholder replaced an existing real app id")

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return False

    print("PASS: existing AdMob app id is preserved and deduplicated")
    return True


def _kts_sample(desugar_lines: str) -> str:
    return f"""plugins {{
    id("com.android.application")
}}

android {{
    namespace = "com.example.old"
    compileSdk = 34

    defaultConfig {{
        applicationId = "com.example.old"
        minSdk = 21
        targetSdk = 34
        versionName = flutter.versionName
    }}

    compileOptions {{
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }}

    kotlinOptions {{
        freeCompilerArgs += listOf(
            buildString {{
                append("}}")
            }},
        )
        jvmTarget = "11"
    }}

    buildTypes {{
        release {{
        }}
    }}
}}

dependencies {{
{desugar_lines}
}}
"""


def _groovy_sample(desugar_lines: str) -> str:
    return f"""plugins {{
    id 'com.android.application'
}}

android {{
    compileSdkVersion 34

    defaultConfig {{
        minSdkVersion 21
        targetSdkVersion 34
    }}

    compileOptions {{
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
        nested {{
            value "}}"
        }}
    }}
}}

dependencies {{
{desugar_lines}
}}
"""


def run_gradle_regression_tests() -> bool:
    print("\n=== Gradle Regression Cases ===")
    cases = (
        ("older", ("2.0.3",)),
        ("previous", ("2.1.4",)),
        ("newer", ("2.1.6",)),
        ("duplicates", ("2.0.3", "2.1.6")),
    )

    all_ok = True
    for name, versions in cases:
        kts_lines = "\n".join(
            "    coreLibraryDesugaring("
            f'"com.android.tools:desugar_jdk_libs:{version}"'
            ")"
            for version in versions
        )
        groovy_lines = "\n".join(
            "    coreLibraryDesugaring "
            f"'com.android.tools:desugar_jdk_libs:{version}'"
            for version in versions
        )

        kts_first = transform_kts(_kts_sample(kts_lines))
        kts_second = transform_kts(kts_first)
        groovy_first = transform_groovy(_groovy_sample(groovy_lines))
        groovy_second = transform_groovy(groovy_first)

        errors: list[str] = []
        if kts_first != kts_second:
            errors.append("KTS transformation is not idempotent")
        if groovy_first != groovy_second:
            errors.append("Groovy transformation is not idempotent")
        if kts_first.count("desugar_jdk_libs") != 1:
            errors.append(
                "KTS desugar dependency count="
                f"{kts_first.count('desugar_jdk_libs')} (expected 1)"
            )
        if groovy_first.count("desugar_jdk_libs") != 1:
            errors.append(
                "Groovy desugar dependency count="
                f"{groovy_first.count('desugar_jdk_libs')} (expected 1)"
            )
        if kts_first.count(DESUGAR_DEP_KTS) != 1:
            errors.append("KTS canonical desugar dependency missing")
        if groovy_first.count(DESUGAR_DEP_GROOVY) != 1:
            errors.append("Groovy canonical desugar dependency missing")
        if "kotlinOptions" in kts_first:
            errors.append("nested KTS kotlinOptions block was not removed")
        if "compilerOptions" not in kts_first:
            errors.append("KTS compilerOptions block was not added")
        if 'value "}"' not in groovy_first:
            errors.append("nested Groovy compileOptions content was damaged")
        if groovy_first.count("kotlinOptions") != 1:
            errors.append(
                "Groovy kotlinOptions count="
                f"{groovy_first.count('kotlinOptions')} (expected 1)"
            )

        if errors:
            all_ok = False
            print(f"FAIL: {name}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"PASS: {name}")

    return all_ok


def run_proguard_preservation_test() -> bool:
    print("\n=== ProGuard Preservation ===")
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        path = root / "android/app/proguard-rules.pro"
        path.parent.mkdir(parents=True)
        custom_rule = "-keep class com.example.CustomRule { *; }"
        path.write_text(
            "# Existing custom rules\n"
            f"{custom_rule}\n"
            f"{PROGUARD_RULES[0]}\n",
            encoding="utf-8",
        )

        ensure_proguard(root)
        first = path.read_bytes()
        ensure_proguard(root)
        second = path.read_bytes()

        errors: list[str] = []
        text = first.decode("utf-8")
        if first != second:
            errors.append("ProGuard output changed on second run")
        if custom_rule not in text:
            errors.append("existing custom ProGuard rule was discarded")
        for rule in PROGUARD_RULES:
            count = text.count(rule)
            if count != 1:
                errors.append(
                    f"ProGuard rule {rule!r}: count={count} (expected 1)"
                )

        if errors:
            for error in errors:
                print(f"FAIL: {error}")
            return False

    print("PASS: custom ProGuard rules preserved; missing rules appended once")
    return True


def run_groovy_and_external_cwd_test() -> bool:
    print("\n=== Groovy + External CWD ===")
    fixture = FIXTURES_DIR / "build.gradle.groovy"
    if not fixture.exists():
        print(f"FAIL: {fixture} does not exist")
        return False

    sample = fixture.read_text(encoding="utf-8")
    first = transform_groovy(sample)
    second = transform_groovy(first)
    if first != second:
        print("FAIL: Groovy transformation is not idempotent")
        return False

    required = (
        "compileSdkVersion 36",
        "minSdkVersion 24",
        "targetSdkVersion 36",
        DESUGAR_DEP_GROOVY,
        "implementation 'com.google.mlkit:text-recognition-japanese:16.0.1'",
    )
    for value in required:
        if first.count(value) != 1:
            print(
                f"FAIL: Groovy value count for {value!r} "
                f"is {first.count(value)}"
            )
            return False

    with tempfile.TemporaryDirectory() as temp:
        temp_root = Path(temp) / "fake_repo"
        tool_dir = temp_root / "tool"
        app_dir = temp_root / "android/app"
        manifest_dir = app_dir / "src/main"
        outside = Path(temp) / "outside"
        tool_dir.mkdir(parents=True)
        manifest_dir.mkdir(parents=True)
        outside.mkdir()

        source_script = REPO_ROOT / "tool/configure_android_release.py"
        copied_script = tool_dir / source_script.name
        shutil.copy2(source_script, copied_script)
        (app_dir / "build.gradle").write_text(sample, encoding="utf-8")
        (app_dir / "proguard-rules.pro").write_text(
            "-keep class com.example.ExternalRule { *; }\n",
            encoding="utf-8",
        )
        (manifest_dir / "AndroidManifest.xml").write_text(
            (FIXTURES_DIR / "001_minimal.xml").read_text(encoding="utf-8"),
            encoding="utf-8",
        )

        first_run = subprocess.run(
            [sys.executable, str(copied_script)],
            cwd=outside,
            text=True,
            capture_output=True,
            check=False,
        )
        if first_run.returncode != 0:
            print(
                "FAIL: external-CWD first run: "
                f"{first_run.stderr or first_run.stdout}"
            )
            return False

        manifest_after_first = (
            manifest_dir / "AndroidManifest.xml"
        ).read_bytes()
        groovy_after_first = (app_dir / "build.gradle").read_bytes()
        proguard_after_first = (app_dir / "proguard-rules.pro").read_bytes()

        second_run = subprocess.run(
            [sys.executable, str(copied_script)],
            cwd=outside,
            text=True,
            capture_output=True,
            check=False,
        )
        if second_run.returncode != 0:
            print(
                "FAIL: external-CWD second run: "
                f"{second_run.stderr or second_run.stdout}"
            )
            return False

        if manifest_after_first != (
            manifest_dir / "AndroidManifest.xml"
        ).read_bytes():
            print("FAIL: external-CWD Manifest changed on second run")
            return False
        if groovy_after_first != (app_dir / "build.gradle").read_bytes():
            print("FAIL: external-CWD Groovy file changed on second run")
            return False
        if proguard_after_first != (
            app_dir / "proguard-rules.pro"
        ).read_bytes():
            print("FAIL: external-CWD ProGuard file changed on second run")
            return False
        if b"com.example.ExternalRule" not in proguard_after_first:
            print("FAIL: external-CWD custom ProGuard rule was discarded")
            return False

        external_errors = validate_manifest(
            manifest_after_first.decode("utf-8")
        )
        if external_errors:
            print(
                "FAIL: external-CWD Manifest invalid: "
                f"{external_errors}"
            )
            return False

    print("PASS: Groovy path and invocation outside repository cwd")
    return True


def main() -> int:
    results = (
        check_production_manifest(),
        run_fixture_tests(),
        run_admob_preservation_test(),
        run_gradle_regression_tests(),
        run_proguard_preservation_test(),
        run_groovy_and_external_cwd_test(),
    )
    print("\n=== Summary ===")
    print("PASS" if all(results) else "FAIL")
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
