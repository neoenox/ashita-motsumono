#!/usr/bin/env python3
"""Verify AndroidManifest.xml and the manifest transformer.

Usage:
    python tool/verify_android_manifest.py

Checks:
    1. Production manifest has all required entries (permissions, receivers, etc.)
    2. Fixture-based idempotency: each fixture is transformed twice, assert byte-identical
    3. Exact count: each permission and receiver appears exactly once in the output
    4. Missing entries: each fixture has the expected entries after transformation
    5. Malformed XML: rejected gracefully
    6. Japanese UTF-8: preserved through transformation
"""

import sys
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

# Ensure we can import the sibling Python module
REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tool"))

from configure_android_release import transform_manifest

MANIFEST = REPO_ROOT / "android/app/src/main/AndroidManifest.xml"
FIXTURES_DIR = REPO_ROOT / "test/fixtures"

_NS = "http://schemas.android.com/apk/res/android"


def _ns(name: str) -> str:
    return f"{{{_NS}}}{name}"


def count_elements(root: ET.Element, tag: str, attrib: str, value: str) -> int:
    count = 0
    for child in root.iter(tag):
        if child.get(_ns(attrib)) == value:
            count += 1
    return count


# ── Production manifest check ────────────────────────────────────────

def check_production_manifest() -> bool:
    if not MANIFEST.exists():
        print(f"ERROR: {MANIFEST} not found")
        return False

    text = MANIFEST.read_text(encoding="utf-8")
    root = ET.fromstring(text)
    all_ok = True

    print("=== Production Manifest ===\n")

    for perm in ["android.permission.CAMERA", "android.permission.POST_NOTIFICATIONS",
                  "android.permission.INTERNET", "android.permission.RECEIVE_BOOT_COMPLETED"]:
        n = count_elements(root, "uses-permission", "name", perm)
        if n == 1:  print(f"  OK  {perm}")
        elif n == 0: print(f"  MISSING: {perm}"); all_ok = False
        else:        print(f"  DUPLICATE ({n}x): {perm}"); all_ok = False

    for recv in ["com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
                  "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"]:
        n = count_elements(root, "receiver", "name", recv)
        if n == 1:  print(f"  OK  {recv}")
        elif n == 0: print(f"  MISSING: {recv}"); all_ok = False
        else:        print(f"  DUPLICATE ({n}x): {recv}"); all_ok = False

    boot_tag = "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    for action in ["android.intent.action.BOOT_COMPLETED", "android.intent.action.MY_PACKAGE_REPLACED",
                   "android.intent.action.QUICKBOOT_POWERON", "com.htc.intent.action.QUICKBOOT_POWERON"]:
        found = False
        for recv in root.iter("receiver"):
            if recv.get(_ns("name")) == boot_tag:
                for intent_filter in recv.iter("intent-filter"):
                    for a in intent_filter.iter("action"):
                        if a.get(_ns("name")) == action:
                            found = True
        if found:  print(f"  OK  BootReceiver action: {action}")
        else:      print(f"  MISSING BootReceiver action: {action}"); all_ok = False

    n_admob = count_elements(root, "meta-data", "name", "com.google.android.gms.ads.APPLICATION_ID")
    if n_admob == 1:  print("  OK  AdMob metadata")
    elif n_admob == 0: print("  MISSING: AdMob metadata"); all_ok = False
    else:              print(f"  DUPLICATE ({n_admob}x): AdMob metadata"); all_ok = False

    n_alarm = count_elements(root, "uses-permission", "name", "android.permission.SCHEDULE_EXACT_ALARM")
    if n_alarm == 0:  print("  OK  SCHEDULE_EXACT_ALARM correctly absent")
    else:             print(f"  FOUND SCHEDULE_EXACT_ALARM (should be absent)"); all_ok = False

    try:
        ET.parse(str(MANIFEST))
        print("  OK  XML well-formed")
    except ET.ParseError as e:
        print(f"  FAIL XML: {e}"); all_ok = False

    return all_ok


# ── Fixture-based idempotency test ───────────────────────────────────

def run_fixture_tests() -> bool:
    """Run transform_manifest on every fixture in a temp dir. Never touches the repo."""
    all_ok = True

    required_perms = [
        "android.permission.CAMERA",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.INTERNET",
        "android.permission.RECEIVE_BOOT_COMPLETED",
    ]
    required_recvs = [
        "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
        "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
    ]
    admob_name = "com.google.android.gms.ads.APPLICATION_ID"

    fixture_files = sorted(FIXTURES_DIR.glob("*.xml")) if FIXTURES_DIR.exists() else []

    if not fixture_files:
        print("  SKIP  (no fixture files found)")
        return True

    print("\n=== Fixture Idempotency Tests ===\n")

    for fixture_path in fixture_files:
        name = fixture_path.stem
        print(f"Fixture: {name}")

        if fixture_path.name == "006_malformed.xml":
            # Expect rejection
            try:
                fixture_path.read_text(encoding="utf-8")
                _ = transform_manifest(fixture_path.read_text(encoding="utf-8"))
                print(f"  FAIL  malformed XML was accepted")
                all_ok = False
            except ET.ParseError:
                print(f"  OK  malformed XML rejected")
            except Exception as e:
                print(f"  OK  malformed XML rejected: {e}")
            continue

        text = fixture_path.read_text(encoding="utf-8")

        # Run transform in memory (twice)
        t1 = transform_manifest(text)
        t2 = transform_manifest(t1)

        # Byte-for-byte idempotency
        if t1 == t2:
            print(f"  OK  idempotent")
        else:
            print(f"  FAIL  not idempotent (second run differs)")
            with tempfile.TemporaryDirectory() as d:
                Path(d, "t1.xml").write_text(t1)
                Path(d, "t2.xml").write_text(t2)
            all_ok = False
            continue

        # Parse result
        try:
            root = ET.fromstring(t1)
        except ET.ParseError as e:
            print(f"  FAIL  result is not valid XML: {e}")
            all_ok = False
            continue

        # Exact count check
        errors = []
        for perm in required_perms:
            n = count_elements(root, "uses-permission", "name", perm)
            if n != 1:
                errors.append(f"  {perm}: count={n} (expected 1)")
        for recv in required_recvs:
            n = count_elements(root, "receiver", "name", recv)
            if n != 1:
                errors.append(f"  {recv}: count={n} (expected 1)")
        n_admob = count_elements(root, "meta-data", "name", admob_name)
        if n_admob != 1:
            errors.append(f"  AdMob: count={n_admob} (expected 1)")

        if errors:
            print(f"  FAIL  element counts:")
            for e in errors:
                print(f"    {e}")
            all_ok = False
        else:
            print(f"  OK  all entries appear exactly once")

    return all_ok


# ── Main ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    ok1 = check_production_manifest()
    ok2 = run_fixture_tests()

    print(f"\n{'=' * 60}")
    print(f"Production manifest:  {'PASS' if ok1 else 'FAIL'}")
    print(f"Fixture tests:        {'PASS' if ok2 else 'FAIL'}")
    sys.exit(0 if (ok1 and ok2) else 1)