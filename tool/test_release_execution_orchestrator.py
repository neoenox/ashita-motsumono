#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

TOOL_DIR = Path(__file__).parent
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

MODULE_PATH = TOOL_DIR / "release_execution_orchestrator.py"
SPEC = importlib.util.spec_from_file_location(
    "release_execution_orchestrator",
    MODULE_PATH,
)
assert SPEC and SPEC.loader
ORCHESTRATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ORCHESTRATOR)
BASE = ORCHESTRATOR.base

SHA = "1" * 40
CERT = "ab" * 32


def play_payload(
    *,
    signing: bool = True,
    submission: bool = True,
) -> dict[str, object]:
    return {
        "applicationId": BASE.APPLICATION_ID,
        "appName": BASE.APP_NAME,
        "defaultLanguage": "ja-JP",
        "appCreated": signing,
        "playAppSigningEnabled": signing,
        "uploadCertificateSha256": CERT if signing else "",
        "iapProductCreated": signing,
        "iapProductId": "remove_ads",
        "iapAiProductCreated": signing,
        "iapAiProductId": "ai_analysis",
        "privacyPolicyRegistered": submission,
        "storeListingComplete": submission,
        "dataSafetyComplete": submission,
        "contentRatingComplete": submission,
        "adsDeclarationComplete": submission,
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
        "repository": BASE.REPOSITORY,
        "commitSha": SHA,
        "android": {
            "applicationId": BASE.APPLICATION_ID,
            "uploadCertificateSha256": CERT,
        },
        "billing": {
            "removeAdsProductId": "remove_ads",
            "aiAccessProductId": "ai_analysis",
        },
        "artifacts": {
            "apk": {
                "artifactName": BASE.APK_ARTIFACT,
                "fileName": "app-release.apk",
                "sha256": "2" * 64,
            },
            "aab": {
                "artifactName": BASE.AAB_ARTIFACT,
                "fileName": "app-release.aab",
                "sha256": "3" * 64,
            },
            "evidence": {
                "artifactName": BASE.EVIDENCE_ARTIFACT,
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


def internal_payload() -> dict[str, object]:
    payload: dict[str, object] = {
        "sourceSha": SHA,
        "releaseRunId": 12345,
    }
    payload.update({key: True for key in BASE._INTERNAL_REQUIRED_TRUE})
    return payload


class OrderedReleaseGateTests(unittest.TestCase):
    def test_signing_passes_before_store_submission_is_complete(self) -> None:
        payload = play_payload(signing=True, submission=False)
        signing = ORCHESTRATOR.validate_play_signing(payload)
        submission = ORCHESTRATOR.validate_play_submission(payload)
        self.assertEqual(signing["result"], "PASS")
        self.assertEqual(submission["result"], "BLOCKED")

    def test_signing_requires_ai_product(self) -> None:
        payload = play_payload()
        payload["iapAiProductCreated"] = False
        payload["iapAiProductId"] = ""
        result = ORCHESTRATOR.validate_play_signing(payload)
        self.assertEqual(result["result"], "BLOCKED")
        self.assertTrue(
            any("iapAiProduct" in value for value in result["failures"])
        )

    def test_signing_rejects_duplicate_product_ids(self) -> None:
        payload = play_payload()
        payload["iapAiProductId"] = payload["iapProductId"]
        result = ORCHESTRATOR.validate_play_signing(payload)
        self.assertEqual(result["result"], "BLOCKED")
        self.assertIn(
            "Play Console billing product IDs must be distinct",
            result["failures"],
        )

    def test_submission_does_not_replace_signing(self) -> None:
        payload = play_payload(signing=False, submission=True)
        self.assertEqual(
            ORCHESTRATOR.validate_play_signing(payload)["result"],
            "BLOCKED",
        )
        self.assertEqual(
            ORCHESTRATOR.validate_play_submission(payload)["result"],
            "PASS",
        )

    def test_release_manifest_requires_matching_ai_product(self) -> None:
        payload = release_payload()
        payload["billing"]["aiAccessProductId"] = "wrong_ai_product"
        result = ORCHESTRATOR.validate_release_manifest(
            payload,
            SHA,
            CERT,
            "remove_ads",
            "ai_analysis",
        )
        self.assertEqual(result["result"], "BLOCKED")
        self.assertTrue(
            any("AI billing product" in value for value in result["failures"])
        )

    def test_next_action_runs_formal_release_before_submission(self) -> None:
        stages = [
            BASE.result("releaseSession", True, [], []),
            BASE.result("issue60", True, [], []),
            BASE.result("playSigning", True, [], []),
            BASE.result("formalRelease", False, [], ["missing"]),
            BASE.result("playSubmission", False, [], ["missing"]),
            BASE.result("internalTest", False, [], ["missing"]),
        ]
        self.assertIn("formal Release Android", ORCHESTRATOR.next_action(stages))

    def test_full_evaluation_uses_ordered_stages(self) -> None:
        session = {
            "schemaVersion": 1,
            "repository": BASE.REPOSITORY,
            "applicationId": BASE.APPLICATION_ID,
            "sourceSha": SHA,
        }
        clean_git = {
            "head": SHA,
            "originMaster": SHA,
            "trackedClean": True,
            "trackedStatus": "",
            "gate": "PASS",
        }
        fixtures = {
            "session": session,
            "issue60": issue60_payload(),
            "play": play_payload(),
            "release": release_payload(),
            "internal": internal_payload(),
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths: dict[str, Path] = {}
            for name, payload in fixtures.items():
                path = root / f"{name}.json"
                path.write_text(json.dumps(payload), encoding="utf-8")
                paths[name] = path
            original = BASE.git_state
            BASE.git_state = lambda _: clean_git
            try:
                report = ORCHESTRATOR.evaluate(
                    root=root,
                    session_path=paths["session"],
                    issue60_path=paths["issue60"],
                    play_console_path=paths["play"],
                    release_manifest_path=paths["release"],
                    internal_test_path=paths["internal"],
                )
            finally:
                BASE.git_state = original
        self.assertEqual(report["recommendation"], "READY_FOR_SUBMISSION")
        self.assertEqual(
            [stage["name"] for stage in report["stages"]],
            [
                "releaseSession",
                "issue60",
                "playSigning",
                "formalRelease",
                "playSubmission",
                "internalTest",
            ],
        )

    def test_incomplete_submission_is_after_formal_release(self) -> None:
        session = {
            "schemaVersion": 1,
            "repository": BASE.REPOSITORY,
            "applicationId": BASE.APPLICATION_ID,
            "sourceSha": SHA,
        }
        clean_git = {
            "head": SHA,
            "originMaster": SHA,
            "trackedClean": True,
            "trackedStatus": "",
            "gate": "PASS",
        }
        fixtures = {
            "session": session,
            "issue60": issue60_payload(),
            "play": play_payload(submission=False),
            "release": release_payload(),
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths: dict[str, Path] = {}
            for name, payload in fixtures.items():
                path = root / f"{name}.json"
                path.write_text(json.dumps(payload), encoding="utf-8")
                paths[name] = path
            original = BASE.git_state
            BASE.git_state = lambda _: clean_git
            try:
                report = ORCHESTRATOR.evaluate(
                    root=root,
                    session_path=paths["session"],
                    issue60_path=paths["issue60"],
                    play_console_path=paths["play"],
                    release_manifest_path=paths["release"],
                    internal_test_path=None,
                )
            finally:
                BASE.git_state = original
        stages = {stage["name"]: stage for stage in report["stages"]}
        self.assertEqual(stages["formalRelease"]["result"], "PASS")
        self.assertEqual(stages["playSubmission"]["result"], "BLOCKED")
        self.assertIn("store listing", report["nextAction"])

    def test_template_contains_both_product_ids(self) -> None:
        payload = ORCHESTRATOR.template_payload("play-console")
        self.assertFalse(payload["iapProductCreated"])
        self.assertEqual(payload["iapProductId"], "remove_ads")
        self.assertFalse(payload["iapAiProductCreated"])
        self.assertEqual(payload["iapAiProductId"], "ai_analysis")


if __name__ == "__main__":
    unittest.main()
