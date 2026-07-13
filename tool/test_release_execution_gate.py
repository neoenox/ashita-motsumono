#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE_PATH = Path(__file__).with_name("release_execution_gate.py")
SPEC = importlib.util.spec_from_file_location(
    "release_execution_gate",
    MODULE_PATH,
)
assert SPEC and SPEC.loader
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)

SHA = "1" * 40
CERT = "ab" * 32


def issue60_payload() -> dict[str, object]:
    common = {
        "SourceSha": SHA,
        "ActualArrivalTime": "2026-07-13T12:00:01+09:00",
        "TitleEvidence": True,
        "VisibleTitle": True,
        "Screen": True,
        "NotificationDump": True,
    }
    return {
        "Recommendation": "ELIGIBLE_FOR_CLOSE_REVIEW",
        "SourceConsistency": True,
        "CurrentSourceMatches": True,
        "Normal": {**common, "Verdict": "PASS"},
        "Reboot": {**common, "Verdict": "PASS"},
        "Install": {
            **common,
            "Verdict": "INCONCLUSIVE",
            "InstallBroadcastVerified": False,
            "InstallBroadcastUnverified": True,
        },
    }


def play_payload() -> dict[str, object]:
    return {
        "applicationId": GATE.APPLICATION_ID,
        "appName": GATE.APP_NAME,
        "defaultLanguage": "ja-JP",
        "appCreated": True,
        "privacyPolicyRegistered": True,
        "playAppSigningEnabled": True,
        "uploadCertificateSha256": CERT,
        "storeListingComplete": True,
        "dataSafetyComplete": True,
        "contentRatingComplete": True,
        "adsDeclarationComplete": True,
        "iapProductCreated": True,
        "iapProductId": "remove_ads",
    }


def certificate(label: str) -> dict[str, object]:
    return {
        "label": label,
        "expectedSha256": CERT,
        "actualSha256": CERT,
        "matches": True,
    }


def release_payload() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "repository": GATE.REPOSITORY,
        "commitSha": SHA,
        "android": {
            "applicationId": GATE.APPLICATION_ID,
            "uploadCertificateSha256": CERT,
        },
        "billing": {"removeAdsProductId": "remove_ads"},
        "artifacts": {
            "apk": {
                "artifactName": GATE.APK_ARTIFACT,
                "fileName": "app-release.apk",
                "sha256": "2" * 64,
            },
            "aab": {
                "artifactName": GATE.AAB_ARTIFACT,
                "fileName": "app-release.aab",
                "sha256": "3" * 64,
            },
            "evidence": {
                "artifactName": GATE.EVIDENCE_ARTIFACT,
                "fileName": "release-manifest.json",
            },
        },
        "certificateVerification": {
            "uploadKeystore": certificate("upload keystore"),
            "apkSigner": certificate("signed APK"),
            "aabSigner": certificate("signed AAB"),
        },
        "githubActions": {"runId": 12345},
    }


def internal_payload() -> dict[str, object]:
    payload: dict[str, object] = {
        "sourceSha": SHA,
        "releaseRunId": 12345,
    }
    payload.update({key: True for key in GATE._INTERNAL_REQUIRED_TRUE})
    return payload


class ReleaseExecutionGateTests(unittest.TestCase):
    def test_issue60_accepts_notification_complete_inconclusive(self) -> None:
        result = GATE.validate_issue60(issue60_payload(), SHA)
        self.assertEqual(result["result"], "PASS")

    def test_issue60_rejects_missing_notification_evidence(self) -> None:
        payload = issue60_payload()
        payload["Install"]["Screen"] = False
        result = GATE.validate_issue60(payload, SHA)
        self.assertEqual(result["result"], "BLOCKED")
        self.assertTrue(
            any(
                "notification-complete" in value
                for value in result["failures"]
            )
        )

    def test_play_console_requires_upload_certificate(self) -> None:
        payload = play_payload()
        payload["uploadCertificateSha256"] = ""
        result = GATE.validate_play_console(payload)
        self.assertEqual(result["result"], "BLOCKED")

    def test_release_manifest_matches_play_console(self) -> None:
        result = GATE.validate_release_manifest(
            release_payload(),
            SHA,
            CERT,
            "remove_ads",
        )
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["runId"], 12345)

    def test_release_manifest_rejects_certificate_mismatch(self) -> None:
        payload = release_payload()
        payload["android"]["uploadCertificateSha256"] = "cd" * 32
        result = GATE.validate_release_manifest(
            payload,
            SHA,
            CERT,
            "remove_ads",
        )
        self.assertEqual(result["result"], "BLOCKED")

    def test_internal_test_requires_every_smoke_check(self) -> None:
        payload = internal_payload()
        payload["restorePassed"] = False
        result = GATE.validate_internal_test(payload, SHA, 12345)
        self.assertEqual(result["result"], "BLOCKED")

    def test_full_evaluate_is_ready_for_submission(self) -> None:
        session = {
            "schemaVersion": 1,
            "repository": GATE.REPOSITORY,
            "applicationId": GATE.APPLICATION_ID,
            "sourceSha": SHA,
        }
        clean_git = {
            "head": SHA,
            "originMaster": SHA,
            "trackedClean": True,
            "trackedStatus": "",
            "gate": "PASS",
        }
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            paths: dict[str, Path] = {}
            fixtures = {
                "session": session,
                "issue60": issue60_payload(),
                "play": play_payload(),
                "release": release_payload(),
                "internal": internal_payload(),
            }
            for name, payload in fixtures.items():
                path = base / f"{name}.json"
                path.write_text(json.dumps(payload), encoding="utf-8")
                paths[name] = path
            original = GATE.git_state
            GATE.git_state = lambda root: clean_git
            try:
                report = GATE.evaluate(
                    root=base,
                    session_path=paths["session"],
                    issue60_path=paths["issue60"],
                    play_console_path=paths["play"],
                    release_manifest_path=paths["release"],
                    internal_test_path=paths["internal"],
                )
            finally:
                GATE.git_state = original
        self.assertEqual(report["recommendation"], "READY_FOR_SUBMISSION")
        self.assertEqual(
            report["nextAction"],
            "submit the release for review and record the public Google Play URL",
        )

    def test_missing_issue60_is_first_next_action(self) -> None:
        session = {
            "schemaVersion": 1,
            "repository": GATE.REPOSITORY,
            "applicationId": GATE.APPLICATION_ID,
            "sourceSha": SHA,
        }
        clean_git = {
            "head": SHA,
            "originMaster": SHA,
            "trackedClean": True,
            "trackedStatus": "",
            "gate": "PASS",
        }
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            session_path = base / "session.json"
            session_path.write_text(json.dumps(session), encoding="utf-8")
            original = GATE.git_state
            GATE.git_state = lambda root: clean_git
            try:
                report = GATE.evaluate(
                    root=base,
                    session_path=session_path,
                    issue60_path=None,
                    play_console_path=None,
                    release_manifest_path=None,
                    internal_test_path=None,
                )
            finally:
                GATE.git_state = original
        self.assertEqual(report["recommendation"], "KEEP_BLOCKED")
        self.assertIn("Issue #60", report["nextAction"])

    def test_templates_default_to_false(self) -> None:
        play = GATE.template_payload("play-console")
        internal = GATE.template_payload("internal-test", SHA)
        self.assertFalse(play["appCreated"])
        self.assertFalse(internal["aabUploaded"])
        self.assertEqual(internal["sourceSha"], SHA)


if __name__ == "__main__":
    unittest.main()
