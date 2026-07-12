from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tool.verify_android_certificate_fingerprint import (
    compare_fingerprints,
    format_fingerprint,
    main,
    normalize_fingerprint,
)


RAW = "0c820ed23c6797780422938445badf3a24e4c3a247aa5b1094ea2bbcbf10b1ed"
COLON = "0C:82:0E:D2:3C:67:97:78:04:22:93:84:45:BA:DF:3A:24:E4:C3:A2:47:AA:5B:10:94:EA:2B:BC:BF:10:B1:ED"
OTHER = "1" * 64


class AndroidCertificateFingerprintTest(unittest.TestCase):
    def test_normalizes_colon_separated_uppercase_value(self) -> None:
        self.assertEqual(normalize_fingerprint(COLON), RAW)

    def test_normalizes_sha256_prefixed_value(self) -> None:
        self.assertEqual(normalize_fingerprint(f"SHA256: {COLON}"), RAW)
        self.assertEqual(normalize_fingerprint(f"sha-256 = {RAW}"), RAW)

    def test_rejects_non_sha256_length(self) -> None:
        with self.assertRaisesRegex(ValueError, "64 hexadecimal digits"):
            normalize_fingerprint("AA:BB")

    def test_rejects_unsupported_characters(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported characters"):
            normalize_fingerprint(f"certificate={RAW}")

    def test_compares_equivalent_formats(self) -> None:
        expected, actual, matches = compare_fingerprints(COLON, RAW)
        self.assertEqual(expected, RAW)
        self.assertEqual(actual, RAW)
        self.assertTrue(matches)

    def test_formats_colon_separated_uppercase_value(self) -> None:
        self.assertEqual(format_fingerprint(RAW), COLON)

    def test_main_writes_success_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "evidence.json"
            argv = [
                "verify_android_certificate_fingerprint.py",
                "--expected",
                f"SHA256: {COLON}",
                "--actual",
                RAW,
                "--label",
                "upload keystore",
                "--output",
                str(output),
            ]
            with mock.patch("sys.argv", argv):
                self.assertEqual(main(), 0)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertTrue(payload["matches"])
            self.assertEqual(payload["actualSha256"], COLON)

    def test_main_fails_and_preserves_mismatch_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "evidence.json"
            argv = [
                "verify_android_certificate_fingerprint.py",
                "--expected",
                RAW,
                "--actual",
                OTHER,
                "--label",
                "signed APK",
                "--output",
                str(output),
            ]
            with mock.patch("sys.argv", argv):
                self.assertEqual(main(), 1)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertFalse(payload["matches"])


if __name__ == "__main__":
    unittest.main()
