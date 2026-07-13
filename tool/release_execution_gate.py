#!/usr/bin/env python3
"""Evaluate the end-to-end Android release evidence for あしたもつもの."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable

REPOSITORY = "kaenozu/ashita-motsumono"
APPLICATION_ID = "com.ashita_motsumono"
APP_NAME = "あしたもつもの"
APK_ARTIFACT = "ashita-motsumono-signed-release-apk"
AAB_ARTIFACT = "ashita-motsumono-signed-release-aab"
EVIDENCE_ARTIFACT = "ashita-motsumono-release-evidence"
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


class EvidenceError(ValueError):
    """Raised when release evidence is malformed."""


def utc_now() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def read_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise EvidenceError(f"{path} must contain a JSON object")
    return payload


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def normalize_sha256(value: Any) -> str:
    normalized = re.sub(r"[:\s-]", "", str(value)).lower()
    if not _SHA256.fullmatch(normalized):
        raise EvidenceError("SHA-256 must contain exactly 64 hexadecimal digits")
    return normalized


def run_git(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise EvidenceError(f"git {' '.join(args)} failed: {detail}")
    return completed.stdout.strip()


def git_state(root: Path) -> dict[str, Any]:
    head = run_git(root, "rev-parse", "HEAD")
    origin_master = run_git(root, "rev-parse", "origin/master")
    tracked_status = run_git(
        root,
        "status",
        "--porcelain",
        "--untracked-files=no",
    )
    gate = "PASS"
    if head != origin_master:
        gate = "HEAD_MISMATCH"
    elif tracked_status:
        gate = "TRACKED_CHANGES"
    return {
        "head": head,
        "originMaster": origin_master,
        "trackedClean": tracked_status == "",
        "trackedStatus": tracked_status,
        "gate": gate,
    }


def start_session(root: Path, output: Path) -> dict[str, Any]:
    state = git_state(root)
    if state["gate"] != "PASS":
        raise EvidenceError(
            f"cannot start release session: git gate is {state['gate']}"
        )
    payload = {
        "schemaVersion": 1,
        "repository": REPOSITORY,
        "applicationId": APPLICATION_ID,
        "sourceSha": state["head"],
        "startedAtUtc": utc_now(),
        "git": state,
        "issueOrder": [60, 98, 59, 94],
        "policy": {
            "sameSourceShaRequired": True,
            "mergeFreezeRequiredUntilIssue60Aggregation": True,
            "staticOrCiEvidenceIsNotNotificationPass": True,
        },
    }
    write_json(output, payload)
    return payload


def result(
    name: str,
    passed: bool,
    facts: Iterable[str],
    failures: Iterable[str],
) -> dict[str, Any]:
    return {
        "name": name,
        "result": "PASS" if passed else "BLOCKED",
        "facts": list(facts),
        "failures": list(failures),
    }


def validate_session(
    session: dict[str, Any],
    current_git: dict[str, Any],
) -> dict[str, Any]:
    facts: list[str] = []
    failures: list[str] = []
    source = str(session.get("sourceSha", ""))
    if session.get("schemaVersion") != 1:
        failures.append("release session schemaVersion must be 1")
    if session.get("repository") != REPOSITORY:
        failures.append(f"repository must be {REPOSITORY}")
    if session.get("applicationId") != APPLICATION_ID:
        failures.append(f"applicationId must be {APPLICATION_ID}")
    if not re.fullmatch(r"[0-9a-f]{40}", source):
        failures.append("session sourceSha must be a 40-digit lowercase Git SHA")
    if current_git.get("gate") != "PASS":
        failures.append(f"current git gate is {current_git.get('gate')}")
    if source and current_git.get("head") != source:
        failures.append("current HEAD differs from release session sourceSha")
    if source and current_git.get("originMaster") != source:
        failures.append("origin/master moved after the release session started")
    if not failures:
        facts.append(f"release session is fixed to {source}")
        facts.append("HEAD, origin/master and tracked worktree are consistent")
    return result("releaseSession", not failures, facts, failures)


def _case_verdict(
    payload: dict[str, Any],
    key: str,
    expected: str,
) -> tuple[dict[str, Any] | None, str | None]:
    value = payload.get(key)
    if not isinstance(value, dict):
        return None, f"Issue #60 summary is missing {key}"
    verdict = value.get("Verdict")
    if verdict != expected:
        return value, (
            f"Issue #60 {key} verdict must be {expected}, got {verdict}"
        )
    return value, None


def validate_issue60(
    payload: dict[str, Any],
    source_sha: str,
) -> dict[str, Any]:
    facts: list[str] = []
    failures: list[str] = []
    if payload.get("Recommendation") != "ELIGIBLE_FOR_CLOSE_REVIEW":
        failures.append(
            "Issue #60 recommendation is not ELIGIBLE_FOR_CLOSE_REVIEW"
        )
    if payload.get("SourceConsistency") is not True:
        failures.append("Issue #60 cases do not share one Source SHA")
    if payload.get("CurrentSourceMatches") is not True:
        failures.append(
            "Issue #60 source does not match the current clean origin/master"
        )

    normal, error = _case_verdict(payload, "Normal", "PASS")
    if error:
        failures.append(error)
    reboot, error = _case_verdict(payload, "Reboot", "PASS")
    if error:
        failures.append(error)

    install = payload.get("Install")
    if not isinstance(install, dict):
        failures.append("Issue #60 summary is missing Install")
    else:
        install_pass = (
            install.get("Verdict") == "PASS"
            and install.get("InstallBroadcastVerified") is True
        )
        install_inconclusive = (
            install.get("Verdict") == "INCONCLUSIVE"
            and install.get("InstallBroadcastUnverified") is True
            and bool(install.get("ActualArrivalTime"))
            and install.get("TitleEvidence") is True
            and install.get("VisibleTitle") is True
            and install.get("Screen") is True
            and install.get("NotificationDump") is True
        )
        if not (install_pass or install_inconclusive):
            failures.append(
                "install-r must be verified PASS, or notification-complete "
                "INCONCLUSIVE limited to unverified MY_PACKAGE_REPLACED "
                "causality"
            )

    for name, case in (
        ("Normal", normal),
        ("Reboot", reboot),
        ("Install", install),
    ):
        if isinstance(case, dict) and case.get("SourceSha") != source_sha:
            failures.append(
                f"Issue #60 {name} SourceSha differs from release session"
            )

    if not failures:
        facts.extend(
            [
                "normal notification evidence passed",
                "reboot notification evidence passed",
                "install-r evidence satisfies the close-review rule",
                f"all Issue #60 cases use {source_sha}",
            ]
        )
    return result("issue60", not failures, facts, failures)


_PLAY_REQUIRED_TRUE = (
    "appCreated",
    "privacyPolicyRegistered",
    "playAppSigningEnabled",
    "storeListingComplete",
    "dataSafetyComplete",
    "contentRatingComplete",
    "adsDeclarationComplete",
    "iapProductCreated",
)


def validate_play_console(payload: dict[str, Any]) -> dict[str, Any]:
    facts: list[str] = []
    failures: list[str] = []
    if payload.get("applicationId") != APPLICATION_ID:
        failures.append(f"Play Console applicationId must be {APPLICATION_ID}")
    if payload.get("appName") != APP_NAME:
        failures.append(f"Play Console appName must be {APP_NAME}")
    if payload.get("defaultLanguage") not in {"ja", "ja-JP"}:
        failures.append("Play Console defaultLanguage must be ja or ja-JP")
    for key in _PLAY_REQUIRED_TRUE:
        if payload.get(key) is not True:
            failures.append(f"Play Console evidence {key} must be true")
    try:
        upload_sha = normalize_sha256(
            payload.get("uploadCertificateSha256", "")
        )
    except EvidenceError as error:
        failures.append(f"invalid Play upload certificate: {error}")
        upload_sha = ""
    product_id = str(payload.get("iapProductId", "")).strip()
    if not product_id:
        failures.append("Play Console iapProductId is required")
    if not failures:
        facts.extend(
            [
                "Play Console app and submission metadata are recorded",
                f"Play upload certificate is {upload_sha}",
                f"Play Billing product is {product_id}",
            ]
        )
    response = result("playConsole", not failures, facts, failures)
    response["uploadCertificateSha256"] = upload_sha
    response["iapProductId"] = product_id
    return response


def validate_release_manifest(
    payload: dict[str, Any],
    source_sha: str,
    upload_sha: str,
    product_id: str,
) -> dict[str, Any]:
    facts: list[str] = []
    failures: list[str] = []
    if payload.get("schemaVersion") != 1:
        failures.append("release manifest schemaVersion must be 1")
    if payload.get("repository") != REPOSITORY:
        failures.append(f"release manifest repository must be {REPOSITORY}")
    if payload.get("commitSha") != source_sha:
        failures.append("release manifest commitSha differs from release session")

    android = payload.get("android")
    if not isinstance(android, dict):
        failures.append("release manifest android section is missing")
        android = {}
    if android.get("applicationId") != APPLICATION_ID:
        failures.append(f"release manifest applicationId must be {APPLICATION_ID}")
    try:
        manifest_upload = normalize_sha256(
            android.get("uploadCertificateSha256", "")
        )
    except EvidenceError as error:
        failures.append(
            f"invalid release manifest upload certificate: {error}"
        )
        manifest_upload = ""
    if upload_sha and manifest_upload and upload_sha != manifest_upload:
        failures.append(
            "Play Console and release manifest upload certificates differ"
        )

    billing = payload.get("billing")
    if (
        not isinstance(billing, dict)
        or billing.get("removeAdsProductId") != product_id
    ):
        failures.append(
            "release manifest billing product differs from Play Console evidence"
        )

    verification = payload.get("certificateVerification")
    if not isinstance(verification, dict):
        failures.append("release manifest certificateVerification is missing")
    else:
        for key in ("uploadKeystore", "apkSigner", "aabSigner"):
            item = verification.get(key)
            if not isinstance(item, dict):
                failures.append(f"certificateVerification.{key} is missing")
                continue
            if item.get("matches") is not True:
                failures.append(
                    f"certificateVerification.{key}.matches must be true"
                )
            try:
                expected = normalize_sha256(item.get("expectedSha256", ""))
                actual = normalize_sha256(item.get("actualSha256", ""))
            except EvidenceError as error:
                failures.append(f"certificateVerification.{key}: {error}")
                continue
            if expected != actual or (upload_sha and expected != upload_sha):
                failures.append(
                    f"certificateVerification.{key} does not match Play Console"
                )

    artifacts = payload.get("artifacts")
    expected_artifacts = {
        "apk": APK_ARTIFACT,
        "aab": AAB_ARTIFACT,
        "evidence": EVIDENCE_ARTIFACT,
    }
    if not isinstance(artifacts, dict):
        failures.append("release manifest artifacts section is missing")
    else:
        for key, expected_name in expected_artifacts.items():
            item = artifacts.get(key)
            if (
                not isinstance(item, dict)
                or item.get("artifactName") != expected_name
            ):
                failures.append(
                    f"release manifest artifact {key} must be {expected_name}"
                )
            if key in {"apk", "aab"} and isinstance(item, dict):
                try:
                    normalize_sha256(item.get("sha256", ""))
                except EvidenceError as error:
                    failures.append(
                        f"release manifest artifact {key}: {error}"
                    )

    actions = payload.get("githubActions")
    if (
        not isinstance(actions, dict)
        or not isinstance(actions.get("runId"), int)
        or actions["runId"] <= 0
    ):
        failures.append(
            "release manifest githubActions.runId must be a positive integer"
        )

    if not failures:
        facts.extend(
            [
                f"formal release Run ID is {actions['runId']}",
                "keystore, APK and AAB certificates match Play Console",
                "APK, AAB and evidence artifact metadata are complete",
            ]
        )
    response = result("formalRelease", not failures, facts, failures)
    response["runId"] = (
        actions.get("runId") if isinstance(actions, dict) else None
    )
    return response


_INTERNAL_REQUIRED_TRUE = (
    "aabUploaded",
    "playInstallSucceeded",
    "cameraOcrPassed",
    "manualFallbackPassed",
    "notificationSmokePassed",
    "notificationDeniedTodoCreationPassed",
    "admobPassed",
    "adFailureFallbackPassed",
    "purchasePassed",
    "restorePassed",
    "aiAnalysisPassed",
    "dataDeletePassed",
    "jsonExportPassed",
)


def validate_internal_test(
    payload: dict[str, Any],
    source_sha: str,
    run_id: int | None,
) -> dict[str, Any]:
    facts: list[str] = []
    failures: list[str] = []
    if payload.get("sourceSha") != source_sha:
        failures.append(
            "internal-test sourceSha differs from release session"
        )
    if payload.get("releaseRunId") != run_id:
        failures.append(
            "internal-test releaseRunId differs from formal release manifest"
        )
    for key in _INTERNAL_REQUIRED_TRUE:
        if payload.get(key) is not True:
            failures.append(f"internal-test evidence {key} must be true")
    if not failures:
        facts.extend(
            [
                "AAB was installed through the Play internal-test track",
                "core OCR, notification, ad, billing, AI and data-management "
                "smoke tests passed",
            ]
        )
    return result("internalTest", not failures, facts, failures)


def missing_stage(name: str, path: Path | None) -> dict[str, Any]:
    return result(
        name,
        False,
        [],
        [f"evidence file is missing: {path or 'not supplied'}"],
    )


def next_action(stages: list[dict[str, Any]]) -> str:
    actions = {
        "releaseSession": (
            "restore the clean release-session source SHA before continuing"
        ),
        "issue60": (
            "complete and aggregate the three Issue #60 emulator "
            "notification cases"
        ),
        "playConsole": (
            "finish Play Console app creation, metadata, signing and product "
            "setup"
        ),
        "formalRelease": (
            "run the formal Release Android workflow and download "
            "release-manifest.json"
        ),
        "internalTest": (
            "upload the AAB to internal testing and complete the "
            "Play-installed smoke tests"
        ),
    }
    for stage in stages:
        if stage["result"] != "PASS":
            return actions[stage["name"]]
    return "submit the release for review and record the public Google Play URL"


def evaluate(
    *,
    root: Path,
    session_path: Path,
    issue60_path: Path | None,
    play_console_path: Path | None,
    release_manifest_path: Path | None,
    internal_test_path: Path | None,
) -> dict[str, Any]:
    session = read_json(session_path)
    source_sha = str(session.get("sourceSha", ""))
    current_git = git_state(root)
    stages: list[dict[str, Any]] = [
        validate_session(session, current_git)
    ]

    if issue60_path and issue60_path.exists():
        stages.append(validate_issue60(read_json(issue60_path), source_sha))
    else:
        stages.append(missing_stage("issue60", issue60_path))

    if play_console_path and play_console_path.exists():
        play = validate_play_console(read_json(play_console_path))
    else:
        play = missing_stage("playConsole", play_console_path)
        play["uploadCertificateSha256"] = ""
        play["iapProductId"] = ""
    stages.append(play)

    if release_manifest_path and release_manifest_path.exists():
        formal = validate_release_manifest(
            read_json(release_manifest_path),
            source_sha,
            str(play.get("uploadCertificateSha256", "")),
            str(play.get("iapProductId", "")),
        )
    else:
        formal = missing_stage("formalRelease", release_manifest_path)
        formal["runId"] = None
    stages.append(formal)

    if internal_test_path and internal_test_path.exists():
        internal = validate_internal_test(
            read_json(internal_test_path),
            source_sha,
            formal.get("runId"),
        )
    else:
        internal = missing_stage("internalTest", internal_test_path)
    stages.append(internal)

    ready = all(stage["result"] == "PASS" for stage in stages)
    return {
        "schemaVersion": 1,
        "generatedAtUtc": utc_now(),
        "repository": REPOSITORY,
        "applicationId": APPLICATION_ID,
        "sourceSha": source_sha,
        "recommendation": (
            "READY_FOR_SUBMISSION" if ready else "KEEP_BLOCKED"
        ),
        "nextAction": next_action(stages),
        "stages": stages,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Android release execution gate",
        "",
        f"- Recommendation: **{report['recommendation']}**",
        f"- Source SHA: `{report['sourceSha']}`",
        f"- Next action: {report['nextAction']}",
        "",
        "| Gate | Result |",
        "|---|---|",
    ]
    for stage in report["stages"]:
        lines.append(f"| {stage['name']} | **{stage['result']}** |")
    lines.extend(["", "## 確認済みの事実"])
    facts = [
        fact
        for stage in report["stages"]
        for fact in stage["facts"]
    ]
    lines.extend([f"- {fact}" for fact in facts] or ["- なし。"])
    lines.extend(["", "## 未確認・BLOCKED"])
    failures = [
        failure
        for stage in report["stages"]
        for failure in stage["failures"]
    ]
    lines.extend(
        [f"- {failure}" for failure in failures] or ["- なし。"]
    )
    lines.extend(
        [
            "",
            "## 推測・仮説",
            "- なし。各ゲートは機械可読な証跡だけで判定する。",
            "",
            "## 反証",
            "- CI、ビルド、静的設定だけを通知・Play配布・課金のPASSとして扱わない。",
            "",
        ]
    )
    return "\n".join(lines)


def template_payload(kind: str, source_sha: str = "") -> dict[str, Any]:
    if kind == "play-console":
        return {
            "schemaVersion": 1,
            "applicationId": APPLICATION_ID,
            "appName": APP_NAME,
            "defaultLanguage": "ja-JP",
            "appCreated": False,
            "privacyPolicyRegistered": False,
            "playAppSigningEnabled": False,
            "uploadCertificateSha256": "",
            "storeListingComplete": False,
            "dataSafetyComplete": False,
            "contentRatingComplete": False,
            "adsDeclarationComplete": False,
            "iapProductCreated": False,
            "iapProductId": "remove_ads",
            "recordedAtUtc": "",
            "notes": "",
        }
    if kind == "internal-test":
        payload = {
            "schemaVersion": 1,
            "sourceSha": source_sha,
            "releaseRunId": 0,
            "testedAtUtc": "",
            "tester": "",
            "notes": "",
        }
        payload.update({key: False for key in _INTERNAL_REQUIRED_TRUE})
        return payload
    raise EvidenceError(f"unknown template kind: {kind}")


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    start = subparsers.add_parser("start-session")
    start.add_argument("--root", type=Path, default=Path("."))
    start.add_argument("--output", type=Path, required=True)

    template = subparsers.add_parser("write-template")
    template.add_argument(
        "--kind",
        choices=("play-console", "internal-test"),
        required=True,
    )
    template.add_argument("--source-sha", default="")
    template.add_argument("--output", type=Path, required=True)

    evaluator = subparsers.add_parser("evaluate")
    evaluator.add_argument("--root", type=Path, default=Path("."))
    evaluator.add_argument("--session", type=Path, required=True)
    evaluator.add_argument("--issue60-summary", type=Path)
    evaluator.add_argument("--play-console-evidence", type=Path)
    evaluator.add_argument("--release-manifest", type=Path)
    evaluator.add_argument("--internal-test-evidence", type=Path)
    evaluator.add_argument("--output-json", type=Path, required=True)
    evaluator.add_argument("--output-markdown", type=Path, required=True)
    evaluator.add_argument("--report-only", action="store_true")

    args = parser.parse_args()
    try:
        if args.command == "start-session":
            payload = start_session(args.root.resolve(), args.output)
            print(f"release session: {args.output}")
            print(f"source SHA: {payload['sourceSha']}")
            return 0
        if args.command == "write-template":
            write_json(
                args.output,
                template_payload(args.kind, args.source_sha),
            )
            print(f"template: {args.output}")
            return 0

        report = evaluate(
            root=args.root.resolve(),
            session_path=args.session,
            issue60_path=args.issue60_summary,
            play_console_path=args.play_console_evidence,
            release_manifest_path=args.release_manifest,
            internal_test_path=args.internal_test_evidence,
        )
        write_json(args.output_json, report)
        args.output_markdown.parent.mkdir(parents=True, exist_ok=True)
        args.output_markdown.write_text(
            render_markdown(report),
            encoding="utf-8",
        )
        print(f"release gate: {report['recommendation']}")
        print(f"next action: {report['nextAction']}")
        if report["recommendation"] == "READY_FOR_SUBMISSION":
            return 0
        return 0 if args.report_only else 1
    except (OSError, EvidenceError, json.JSONDecodeError) as error:
        print(
            f"::error::release execution gate failed: {error}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
