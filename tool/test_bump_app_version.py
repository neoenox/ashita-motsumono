from __future__ import annotations

import json
import tempfile
from pathlib import Path
import unittest

from tool.bump_app_version import (
    build_report,
    read_current_version,
    target_version_code,
    write_version,
)


def _write(path: Path, text: str) -> Path:
    path.write_text(text, encoding="utf-8")
    return path


class BumpAppVersionTest(unittest.TestCase):
    def test_target_keeps_current_when_free(self) -> None:
        self.assertEqual(target_version_code(6, [3, 5]), (6, False))

    def test_target_bumps_when_current_is_used(self) -> None:
        self.assertEqual(target_version_code(5, [3, 5]), (6, True))

    def test_target_bumps_when_current_below_max_used(self) -> None:
        # 4 was superseded: absent from the active list but still non-reusable.
        self.assertEqual(target_version_code(4, [3, 5]), (6, True))

    def test_target_keeps_current_when_history_empty(self) -> None:
        self.assertEqual(target_version_code(1, []), (1, False))

    def test_target_bumps_when_current_itself_is_used(self) -> None:
        self.assertEqual(target_version_code(7, [7]), (8, True))

    def test_read_current_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pubspec = _write(
                Path(tmp) / "pubspec.yaml",
                "name: ashita_motsumono\nversion: 0.7.0+6\n",
            )
            self.assertEqual(read_current_version(pubspec), ("0.7.0", 6))

    def test_read_current_version_without_build_number_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pubspec = _write(Path(tmp) / "pubspec.yaml", "version: 0.7.0\n")
            with self.assertRaises(ValueError):
                read_current_version(pubspec)

    def test_write_version_updates_pubspec_and_generated(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pubspec = _write(
                root / "pubspec.yaml",
                "name: ashita_motsumono\nversion: 0.7.0+6\n",
            )
            generated = _write(root / "app_version.g.dart", "old")
            write_version(pubspec, generated, "0.7.0+7")
            self.assertIn("version: 0.7.0+7", pubspec.read_text(encoding="utf-8"))
            rendered = generated.read_text(encoding="utf-8")
            self.assertIn("const appVersion = '0.7.0+7';", rendered)
            self.assertIn("GENERATED FILE", rendered)

    def test_write_version_requires_existing_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pubspec = _write(Path(tmp) / "pubspec.yaml", "name: x\n")
            with self.assertRaises(ValueError):
                write_version(pubspec, Path(tmp) / "g.dart", "0.7.0+7")

    def test_report_no_change(self) -> None:
        report = build_report(
            name="0.7.0",
            current_name="0.7.0",
            current_code=6,
            used_codes=[3, 5],
            target_code=6,
            bumped=False,
            applied=False,
        )
        self.assertEqual(report["result"], "NO_CHANGE")
        self.assertEqual(report["nextFreeVersionCode"], 6)
        self.assertIn("変更不要", report["message"])

    def test_report_bumped_with_suggested_commit(self) -> None:
        report = build_report(
            name="0.7.0",
            current_name="0.7.0",
            current_code=5,
            used_codes=[3, 5],
            target_code=6,
            bumped=True,
            applied=True,
        )
        self.assertEqual(report["result"], "BUMPED")
        self.assertEqual(report["targetVersion"], "0.7.0+6")
        self.assertTrue(report["applied"])
        self.assertIn("0.7.0+6", report["suggestedCommit"])
        self.assertIn("使用済み = 3, 5", report["suggestedCommit"])

    def test_main_dry_run_against_real_used_codes_shape(self) -> None:
        # Mirrors the fastlane play_preflight output consumed by main().
        payload = {
            "packageName": "com.ashita_motsumono",
            "usedVersionCodes": [3, 5],
            "tracks": {"alpha": [3], "internal": [5]},
            "apkVersionCodes": [],
            "fetchedAtUtc": "2026-08-17T00:00:00Z",
        }
        with tempfile.TemporaryDirectory() as tmp:
            used = _write(Path(tmp) / "used.json", json.dumps(payload))
            pubspec = _write(
                Path(tmp) / "pubspec.yaml",
                "name: ashita_motsumono\nversion: 0.7.0+6\n",
            )
            import subprocess
            import sys

            result = subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).resolve().parents[1] / "tool" / "bump_app_version.py"),
                    "--used-codes",
                    str(used),
                    "--pubspec",
                    str(pubspec),
                ],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            report = json.loads(result.stdout)
            self.assertEqual(report["result"], "NO_CHANGE")
            self.assertEqual(report["targetVersion"], "0.7.0+6")


if __name__ == "__main__":
    unittest.main()
