#!/usr/bin/env python3
"""Ordered Android release orchestration built on release_execution_gate."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

import release_execution_gate as base

_SIGNING_REQUIRED_TRUE = (
    "appCreated",
    "playAppSigningEnabled",
    "iapProductCreated",
    "iapAiProductCreated",
)
_SUBMISSION_REQUIRED_TRUE = (
    "privacyPolicyRegistered",
    "storeListingComplete",
    "dataSafetyComplete",
    "contentRatingComplete",
    "adsDeclarationComplete",
)


def _validate_identity(payload: dict[str, Any], failures: list[str]) -> None:
    if payload.get("applicationId") != base.APPLICATION_ID:
        failures.append(
            f"Play Console applicationId must be {base.APPLICATION_ID}"
        )
    if payload.get("appName") != base.APP_NAME:
        failures.append(f"Play Console appName must be {base.APP_NAME}")
    if payload.get("defaultLanguage") not in {"ja", "ja-JP"}:
        failures.append("Play Console defaultLanguage must be ja or ja-JP")


def validate_play_signing(payload: dict[str, Any]) -> dict[str, Any]:
    facts: list[str] = []
    failures: list[str] = []
    _validate_identity(payload, failures)
    for key in _SIGNING_REQUIRED_TRUE:
        if payload.get(key) is not True:
            failures.append(f"Play signing evidence {key} must be true")
    try:
        upload_sha = base.normalize_sha256(
            payload.get("uploadCertificateSha256", "")
        )
    except base.EvidenceError as error:
        failures.append(f"invalid Play upload certificate: {error}")
        upload_sha = ""
    product_id = str(payload.get("iapProductId", "")).strip()
    if not product_id:
        failures.append("Play Console iapProductId is required")
    ai_product_id = str(payload.get("iapAiProductId", "")).strip()
    if not ai_product_id:
        failures.append("Play Console iapAiProductId is required")
    if not failures:
        facts.extend(
            [
                "Play Console app, Play App Signing and products are ready",
                f"Play upload certificate is {upload_sha}",
                f"Play Billing products are {product_id} and {ai_product_id}",
            ]
        )
    response = base.result("playSigning", not failures, facts, failures)
    response["uploadCertificateSha256"] = upload_sha
    response["iapProductId"] = product_id
    response["iapAiProductId"] = ai_product_id
    return response


def validate_play_submission(payload: dict[str, Any]) -> dict[str, Any]:
    facts: list[str] = []
    failures: list[str] = []
    _validate_identity(payload, failures)
    for key in _SUBMISSION_REQUIRED_TRUE:
        if payload.get(key) is not True:
            failures.append(f"Play submission evidence {key} must be true")
    if not failures:
        facts.append(
            "privacy policy, store listing, Data Safety, content rating and "
            "ads declaration are complete"
        )
    return base.result("playSubmission", not failures, facts, failures)


def validate_release_manifest(
    payload: dict[str, Any],
    source_sha: str,
    upload_sha: str,
    product_id: str,
    ai_product_id: str,
) -> dict[str, Any]:
    response = base.validate_release_manifest(
        payload,
        source_sha,
        upload_sha,
        product_id,
    )
    failures = list(response["failures"])
    facts = list(response["facts"])
    billing = payload.get("billing")
    if (
        not isinstance(billing, dict)
        or billing.get("aiAccessProductId") != ai_product_id
    ):
        failures.append(
            "release manifest AI billing product differs from Play Console evidence"
        )
    if not failures:
        facts.append(f"AI billing product is {ai_product_id}")
    response["result"] = "PASS" if not failures else "BLOCKED"
    response["facts"] = facts
    response["failures"] = failures
    return response


def next_action(stages: list[dict[str, Any]]) -> str:
    actions = {
        "releaseSession": (
            "restore the clean release-session source SHA before continuing"
        ),
        "issue60": (
            "complete and aggregate the three Issue #60 emulator "
            "notification cases"
        ),
        "playSigning": (
            "create the Play app, enable Play App Signing, record the upload "
            "certificate, and create both billing products"
        ),
        "formalRelease": (
            "run the formal Release Android workflow and download "
            "release-manifest.json"
        ),
        "playSubmission": (
            "complete the Play store listing, privacy policy, Data Safety, "
            "content rating and ads declaration"
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
    session = base.read_json(session_path)
    source_sha = str(session.get("sourceSha", ""))
    stages: list[dict[str, Any]] = [
        base.validate_session(session, base.git_state(root))
    ]

    if issue60_path and issue60_path.exists():
        stages.append(
            base.validate_issue60(base.read_json(issue60_path), source_sha)
        )
    else:
        stages.append(base.missing_stage("issue60", issue60_path))

    if play_console_path and play_console_path.exists():
        play_payload = base.read_json(play_console_path)
        signing = validate_play_signing(play_payload)
    else:
        play_payload = None
        signing = base.missing_stage("playSigning", play_console_path)
        signing["uploadCertificateSha256"] = ""
        signing["iapProductId"] = ""
        signing["iapAiProductId"] = ""
    stages.append(signing)

    if release_manifest_path and release_manifest_path.exists():
        formal = validate_release_manifest(
            base.read_json(release_manifest_path),
            source_sha,
            str(signing.get("uploadCertificateSha256", "")),
            str(signing.get("iapProductId", "")),
            str(signing.get("iapAiProductId", "")),
        )
    else:
        formal = base.missing_stage("formalRelease", release_manifest_path)
        formal["runId"] = None
    stages.append(formal)

    if play_payload is not None:
        submission = validate_play_submission(play_payload)
    else:
        submission = base.missing_stage("playSubmission", play_console_path)
    stages.append(submission)

    if internal_test_path and internal_test_path.exists():
        internal = base.validate_internal_test(
            base.read_json(internal_test_path),
            source_sha,
            formal.get("runId"),
        )
    else:
        internal = base.missing_stage("internalTest", internal_test_path)
    stages.append(internal)

    ready = all(stage["result"] == "PASS" for stage in stages)
    return {
        "schemaVersion": 2,
        "generatedAtUtc": base.utc_now(),
        "repository": base.REPOSITORY,
        "applicationId": base.APPLICATION_ID,
        "sourceSha": source_sha,
        "issueOrder": [60, 98, 59, 94],
        "gateOrder": [
            "releaseSession",
            "issue60",
            "playSigning",
            "formalRelease",
            "playSubmission",
            "internalTest",
        ],
        "recommendation": (
            "READY_FOR_SUBMISSION" if ready else "KEEP_BLOCKED"
        ),
        "nextAction": next_action(stages),
        "stages": stages,
    }


def template_payload(kind: str, source_sha: str = "") -> dict[str, Any]:
    payload = base.template_payload(kind, source_sha)
    if kind == "play-console":
        payload["iapAiProductCreated"] = False
        payload["iapAiProductId"] = "ai_analysis"
    return payload


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
            payload = base.start_session(args.root.resolve(), args.output)
            print(f"release session: {args.output}")
            print(f"source SHA: {payload['sourceSha']}")
            return 0
        if args.command == "write-template":
            base.write_json(
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
        base.write_json(args.output_json, report)
        args.output_markdown.parent.mkdir(parents=True, exist_ok=True)
        args.output_markdown.write_text(
            base.render_markdown(report),
            encoding="utf-8",
        )
        print(f"release gate: {report['recommendation']}")
        print(f"next action: {report['nextAction']}")
        if report["recommendation"] == "READY_FOR_SUBMISSION":
            return 0
        return 0 if args.report_only else 1
    except (OSError, base.EvidenceError, json.JSONDecodeError) as error:
        print(
            f"::error::release execution orchestrator failed: {error}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
