from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tool.generate_release_manifest import (
    build_manifest,
    read_application_id,
    read_pubspec_version,
)

FINGERPRINT = "0C:82:0E:D2:3C:67:97:78:04:22:93:84:45:BA:DF:3A:24:E4:C3:A2:47:AA:5B:10:94:EA:2B:BC:BF:10:B1:ED"
ENVIRONMENT = {
    "GITHUB_REPOSITORY": "kaenozu/ashita-motsumono",
    "GITHUB_SHA": "e63bd5cebda22fce6bfeda38c6ede332a29ebb88",
    "GITHUB_REF": "refs/heads/master",
    "GITHUB_RUN_ID": "29197023560",
    "GITHUB_RUN_ATTEMPT": "1",
    "GITHUB_WORKFLOW": "Flutter CI",
    "GITHUB_EVENT_NAME": "workflow_dispatch",
}


class ReleaseManifestTest(unittest.TestCase):
    def test_reads_pubspec_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "pubspec.yaml"
            path.write_text("name: example\nversion: 0.6.3+2\n", encoding="utf-8")
            self.assertEqual(read_pubspec_version(path), ("0.6.3", 2))

    def test_reads_kotlin_application_id(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gradle = root / "android/app/build.gradle.kts"
            gradle.parent.mkdir(parents=True)
            gradle.write_text(
                'android { defaultConfig { applicationId = "com.ashita_motsumono" } }\n',
                encoding="utf-8",
            )
            self.assertEqual(read_application_id(root), "com.ashita_motsumono")

    def test_builds_manifest_from_verified_release_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = self._write_fixture(root)
            manifest = self._build(root, paths)

            self.assertEqual(manifest["version"], {"name": "0.6.3", "code": 2})
            self.assertEqual(
                manifest["android"]["applicationId"],
                "com.ashita_motsumono",
            )
            self.assertEqual(
                manifest["android"]["uploadCertificateSha256"],
                FINGERPRINT,
            )
            self.assertEqual(
                manifest["billing"],
                {
                    "removeAdsProductId": "remove_ads",
                    "aiAccessProductId": "ai_analysis",
                },
            )
            self.assertEqual(manifest["githubActions"]["runId"], 29197023560)
            self.assertTrue(
                manifest["certificateVerification"]["aabSigner"]["matches"]
            )

    def test_rejects_binary_hash_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = self._write_fixture(root)
            paths["apk_sums"].write_text(f"{'0' * 64}  app-release.apk\n")
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                self._build(root, paths)

    def test_rejects_unsuccessful_certificate_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = self._write_fixture(root)
            payload = json.loads(
                paths["aab_certificate"].read_text(encoding="utf-8")
            )
            payload["matches"] = False
            paths["aab_certificate"].write_text(
                json.dumps(payload),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "successful certificate match"):
                self._build(root, paths)

    def _build(self, root: Path, paths: dict[str, Path]) -> dict[str, object]:
        return build_manifest(
            root=root,
            apk=paths["apk"],
            aab=paths["aab"],
            apk_sums=paths["apk_sums"],
            aab_sums=paths["aab_sums"],
            upload_certificate=paths["upload_certificate"],
            apk_certificate=paths["apk_certificate"],
            aab_certificate=paths["aab_certificate"],
            iap_product_id="remove_ads",
            iap_ai_product_id="ai_analysis",
            apk_artifact_name="ashita-motsumono-signed-release-apk",
            aab_artifact_name="ashita-motsumono-signed-release-aab",
            evidence_artifact_name="ashita-motsumono-release-evidence",
            environment=ENVIRONMENT,
            generated_at=datetime(2026, 7, 13, 0, 0, tzinfo=timezone.utc),
        )

    def _write_fixture(self, root: Path) -> dict[str, Path]:
        (root / "pubspec.yaml").write_text(
            "name: ashita_motsumono\nversion: 0.6.3+2\n",
            encoding="utf-8",
        )
        gradle = root / "android/app/build.gradle.kts"
        gradle.parent.mkdir(parents=True)
        gradle.write_text(
            'android { defaultConfig { applicationId = "com.ashita_motsumono" } }\n',
            encoding="utf-8",
        )

        output = root / "build/release-verification"
        output.mkdir(parents=True)
        apk = root / "build/app/outputs/flutter-apk/app-release.apk"
        aab = root / "build/app/outputs/bundle/release/app-release.aab"
        apk.parent.mkdir(parents=True)
        aab.parent.mkdir(parents=True)
        apk.write_bytes(b"apk")
        aab.write_bytes(b"aab")

        apk_sums = output / "APK_SHA256SUMS"
        aab_sums = output / "AAB_SHA256SUMS"
        apk_sums.write_text(
            f"{hashlib.sha256(apk.read_bytes()).hexdigest()}  {apk}\n",
            encoding="utf-8",
        )
        aab_sums.write_text(
            f"{hashlib.sha256(aab.read_bytes()).hexdigest()}  {aab}\n",
            encoding="utf-8",
        )

        certificates = {
            "upload_certificate": (
                "upload-keystore-certificate.json",
                "upload keystore",
            ),
            "apk_certificate": ("apk-certificate.json", "signed APK"),
            "aab_certificate": ("aab-certificate.json", "signed AAB"),
        }
        paths: dict[str, Path] = {
            "apk": apk,
            "aab": aab,
            "apk_sums": apk_sums,
            "aab_sums": aab_sums,
        }
        for key, (name, label) in certificates.items():
            path = output / name
            path.write_text(
                json.dumps(
                    {
                        "label": label,
                        "expectedSha256": FINGERPRINT,
                        "actualSha256": FINGERPRINT,
                        "matches": True,
                    }
                ),
                encoding="utf-8",
            )
            paths[key] = path
        return paths


if __name__ == "__main__":
    unittest.main()
