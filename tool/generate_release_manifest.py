#!/usr/bin/env python3
"""Generate machine-readable evidence for an Android release build."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from typing import Mapping


_VERSION_PATTERN = re.compile(r"^version:\s*([^\s#]+)\s*$", re.MULTILINE)
_KTS_APPLICATION_ID_PATTERN = re.compile(r'applicationId\s*=\s*"([^"]+)"')
_GROOVY_APPLICATION_ID_PATTERN = re.compile(
    r"""applicationId\s+["']([^"']+)["']"""
)
_SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
_REQUIRED_GITHUB_ENV = (
    "GITHUB_REPOSITORY",
    "GITHUB_SHA",
    "GITHUB_REF",
    "GITHUB_RUN_ID",
    "GITHUB_RUN_ATTEMPT",
    "GITHUB_WORKFLOW",
    "GITHUB_EVENT_NAME",
)


def normalize_sha256(value: str) -> str:
    normalized = re.sub(r"[:\s-]", "", value).lower()
    if not _SHA256_PATTERN.fullmatch(normalized):
        raise ValueError("SHA-256 must contain exactly 64 hexadecimal digits")
    return normalized


def format_sha256(value: str) -> str:
    normalized = normalize_sha256(value)
    return ":".join(
        normalized[index : index + 2].upper()
        for index in range(0, len(normalized), 2)
    )


def read_pubspec_version(path: Path) -> tuple[str, int]:
    match = _VERSION_PATTERN.search(path.read_text(encoding="utf-8"))
    if match is None:
        raise ValueError(f"version was not found in {path}")
    raw_version = match.group(1)
    if "+" not in raw_version:
        raise ValueError("pubspec version must include a numeric build number")
    version_name, version_code_text = raw_version.rsplit("+", 1)
    if not version_name or not version_code_text.isdigit():
        raise ValueError(f"invalid pubspec version: {raw_version}")
    return version_name, int(version_code_text)


def read_application_id(root: Path) -> str:
    candidates = (
        (
            root / "android/app/build.gradle.kts",
            _KTS_APPLICATION_ID_PATTERN,
        ),
        (
            root / "android/app/build.gradle",
            _GROOVY_APPLICATION_ID_PATTERN,
        ),
    )
    for path, pattern in candidates:
        if not path.exists():
            continue
        match = pattern.search(path.read_text(encoding="utf-8"))
        if match is not None:
            return match.group(1)
    raise ValueError("Android applicationId was not found in generated Gradle files")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_recorded_sha256(path: Path) -> str:
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()]
    lines = [line for line in lines if line]
    if len(lines) != 1:
        raise ValueError(f"{path} must contain exactly one SHA-256 record")
    return normalize_sha256(lines[0].split()[0])


def verify_binary_hash(binary: Path, sums_file: Path) -> str:
    actual = sha256_file(binary)
    recorded = read_recorded_sha256(sums_file)
    if actual != recorded:
        raise ValueError(
            f"SHA-256 mismatch for {binary}: recorded {recorded}, actual {actual}"
        )
    return actual


def read_certificate_evidence(path: Path, expected_label: str) -> dict[str, object]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("label") != expected_label:
        raise ValueError(
            f"{path} label must be {expected_label!r}, got {payload.get('label')!r}"
        )
    expected = normalize_sha256(str(payload.get("expectedSha256", "")))
    actual = normalize_sha256(str(payload.get("actualSha256", "")))
    matches = payload.get("matches")
    if matches is not True or expected != actual:
        raise ValueError(f"{path} does not contain a successful certificate match")
    return {
        "label": expected_label,
        "expectedSha256": format_sha256(expected),
        "actualSha256": format_sha256(actual),
        "matches": True,
    }


def require_github_environment(environment: Mapping[str, str]) -> dict[str, str]:
    missing = [name for name in _REQUIRED_GITHUB_ENV if not environment.get(name)]
    if missing:
        raise ValueError(
            "missing GitHub Actions environment values: " + ", ".join(missing)
        )
    return {name: environment[name] for name in _REQUIRED_GITHUB_ENV}


def build_manifest(
    *,
    root: Path,
    apk: Path,
    aab: Path,
    apk_sums: Path,
    aab_sums: Path,
    upload_certificate: Path,
    apk_certificate: Path,
    aab_certificate: Path,
    iap_product_id: str,
    apk_artifact_name: str,
    aab_artifact_name: str,
    evidence_artifact_name: str,
    environment: Mapping[str, str],
    generated_at: datetime | None = None,
) -> dict[str, object]:
    github = require_github_environment(environment)
    version_name, version_code = read_pubspec_version(root / "pubspec.yaml")
    application_id = read_application_id(root)

    certificate_evidence = {
        "uploadKeystore": read_certificate_evidence(
            upload_certificate, "upload keystore"
        ),
        "apkSigner": read_certificate_evidence(apk_certificate, "signed APK"),
        "aabSigner": read_certificate_evidence(aab_certificate, "signed AAB"),
    }
    fingerprints = {
        item["expectedSha256"] for item in certificate_evidence.values()
    }
    if len(fingerprints) != 1:
        raise ValueError("certificate evidence files do not share one expected SHA-256")
    upload_sha256 = fingerprints.pop()

    apk_sha256 = verify_binary_hash(apk, apk_sums)
    aab_sha256 = verify_binary_hash(aab, aab_sums)

    timestamp = generated_at or datetime.now(timezone.utc)
    if timestamp.tzinfo is None:
        raise ValueError("generated_at must be timezone-aware")
    generated_at_utc = (
        timestamp.astimezone(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )

    return {
        "schemaVersion": 1,
        "generatedAtUtc": generated_at_utc,
        "repository": github["GITHUB_REPOSITORY"],
        "commitSha": github["GITHUB_SHA"],
        "ref": github["GITHUB_REF"],
        "version": {
            "name": version_name,
            "code": version_code,
        },
        "android": {
            "applicationId": application_id,
            "uploadCertificateSha256": upload_sha256,
        },
        "billing": {
            "removeAdsProductId": iap_product_id,
        },
        "artifacts": {
            "apk": {
                "artifactName": apk_artifact_name,
                "fileName": apk.name,
                "sha256": apk_sha256,
            },
            "aab": {
                "artifactName": aab_artifact_name,
                "fileName": aab.name,
                "sha256": aab_sha256,
            },
            "evidence": {
                "artifactName": evidence_artifact_name,
                "fileName": "release-manifest.json",
            },
        },
        "certificateVerification": certificate_evidence,
        "githubActions": {
            "runId": int(github["GITHUB_RUN_ID"]),
            "runAttempt": int(github["GITHUB_RUN_ATTEMPT"]),
            "workflow": github["GITHUB_WORKFLOW"],
            "eventName": github["GITHUB_EVENT_NAME"],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--aab", type=Path, required=True)
    parser.add_argument("--apk-sums", type=Path, required=True)
    parser.add_argument("--aab-sums", type=Path, required=True)
    parser.add_argument("--upload-certificate", type=Path, required=True)
    parser.add_argument("--apk-certificate", type=Path, required=True)
    parser.add_argument("--aab-certificate", type=Path, required=True)
    parser.add_argument("--iap-product-id", required=True)
    parser.add_argument(
        "--apk-artifact-name",
        default="ashita-motsumono-signed-release-apk",
    )
    parser.add_argument(
        "--aab-artifact-name",
        default="ashita-motsumono-signed-release-aab",
    )
    parser.add_argument(
        "--evidence-artifact-name",
        default="ashita-motsumono-release-evidence",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        manifest = build_manifest(
            root=args.root,
            apk=args.apk,
            aab=args.aab,
            apk_sums=args.apk_sums,
            aab_sums=args.aab_sums,
            upload_certificate=args.upload_certificate,
            apk_certificate=args.apk_certificate,
            aab_certificate=args.aab_certificate,
            iap_product_id=args.iap_product_id,
            apk_artifact_name=args.apk_artifact_name,
            aab_artifact_name=args.aab_artifact_name,
            evidence_artifact_name=args.evidence_artifact_name,
            environment=os.environ,
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"::error::release manifest generation failed: {error}", file=sys.stderr)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"release manifest: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
