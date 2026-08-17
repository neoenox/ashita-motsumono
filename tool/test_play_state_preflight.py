from __future__ import annotations

import json
import tempfile
from pathlib import Path
import unittest

from tool.play_state_preflight import (
    evaluate,
    read_certificate_status,
    read_pubspec_version_code,
    read_used_codes,
)


def _write(path: Path, text: str) -> Path:
    path.write_text(text, encoding="utf-8")
    return path


class PlayStatePreflightTest(unittest.TestCase):
    def test_pubspec_version_code_is_parsed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pubspec = _write(
                Path(tmp) / "pubspec.yaml",
                "name: ashita_motsumono\nversion: 0.7.0+5\n",
            )
            self.assertEqual(read_pubspec_version_code(pubspec), 5)

    def test_pubspec_without_build_number_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            pubspec = _write(
                Path(tmp) / "pubspec.yaml",
                "version: 0.7.0\n",
            )
            with self.assertRaises(ValueError):
                read_pubspec_version_code(pubspec)

    def test_used_codes_are_read_and_sorted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            payload = _write(
                Path(tmp) / "used.json",
                json.dumps(
                    {
                        "packageName": "com.ashita_motsumono",
                        "usedVersionCodes": [5, 3, 4, 3],
                        "tracks": {"internal": [3, 5], "alpha": [4]},
                        "apkVersionCodes": [],
                        "fetchedAtUtc": "2026-08-17T00:00:00Z",
                    }
                ),
            )
            self.assertEqual(
                read_used_codes(payload),
                {
                    "packageName": "com.ashita_motsumono",
                    "fetchedAtUtc": "2026-08-17T00:00:00Z",
                    "usedVersionCodes": [3, 4, 5],
                    "tracks": {"internal": [3, 5], "alpha": [4]},
                    "apkVersionCodes": [],
                },
            )

    def test_collision_blocks_with_next_free_code(self) -> None:
        result = evaluate([1, 2, 3, 4, 5], 5)
        self.assertEqual(result["result"], "BLOCKED")
        self.assertFalse(result["versionCodeAvailable"])
        self.assertEqual(result["nextFreeVersionCode"], 6)
        self.assertIn("use 6 instead", result["errors"][0])
        self.assertIn("Bump pubspec.yaml versionCode to 6", result["nextActions"][0])

    def test_free_code_passes(self) -> None:
        result = evaluate([1, 2, 3, 4, 5], 6)
        self.assertEqual(result["result"], "PASS")
        self.assertTrue(result["versionCodeAvailable"])
        self.assertEqual(result["nextFreeVersionCode"], 6)
        self.assertEqual(result["errors"], [])

    def test_empty_play_state_suggests_one(self) -> None:
        result = evaluate([], 1)
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["nextFreeVersionCode"], 1)

    def test_certificate_mismatch_blocks(self) -> None:
        certificate = {
            "status": "mismatched",
            "expectedSha256": "AA",
            "actualSha256": "BB",
            "matches": False,
        }
        result = evaluate([1, 2], 3, certificate=certificate)
        self.assertEqual(result["result"], "BLOCKED")
        self.assertIn("certificate", result["errors"][0])

    def test_certificate_matched_does_not_block(self) -> None:
        certificate = {
            "status": "matched",
            "expectedSha256": "AA",
            "actualSha256": "AA",
            "matches": True,
        }
        result = evaluate([1, 2], 3, certificate=certificate)
        self.assertEqual(result["result"], "PASS")

    def test_certificate_status_absent_is_not_checked(self) -> None:
        self.assertEqual(read_certificate_status(None), {"status": "notChecked"})

    def test_certificate_status_reads_evidence_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            payload = _write(
                Path(tmp) / "certificate.json",
                json.dumps(
                    {
                        "label": "upload keystore",
                        "expectedSha256": "AA",
                        "actualSha256": "AA",
                        "matches": True,
                    }
                ),
            )
            status = read_certificate_status(payload)
            self.assertEqual(status["status"], "matched")
            self.assertTrue(status["matches"])

    def test_registered_certificate_note_is_explicit(self) -> None:
        result = evaluate([1, 2], 3)
        self.assertIn("does not expose the upload certificate", result["registeredCertificateNote"])


if __name__ == "__main__":
    unittest.main()
