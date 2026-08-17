#!/usr/bin/env python3
"""Decide whether the pubspec versionCode is still available on Google Play.

The used-version-code list is fetched by the fastlane `play_preflight` lane using the
Google Play service account. This tool reads that list plus pubspec.yaml, performs the
fail-fast decision, and writes evidence. It never reads secret values.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

PUBSPEC_VERSION_PATTERN = re.compile(r"^version:\s*([^\s#]+)\+(\d+)\s*$", re.MULTILINE)

REGISTERED_CERTIFICATE_NOTE = (
    "The Play Developer API does not expose the upload certificate registered in "
    "Play Console. The keystore-vs-variable comparison and upload acceptance "
    "(validate_only) are the automated checks for that certificate."
)


def read_pubspec_version_code(path: Path) -> int:
    match = PUBSPEC_VERSION_PATTERN.search(path.read_text(encoding="utf-8"))
    if match is None:
        raise ValueError(f"pubspec version must use <name>+<build-number>: {path}")
    return int(match.group(2))


def read_used_codes(path: Path) -> dict[str, object]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    try:
        codes = [int(code) for code in payload["usedVersionCodes"]]
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f"used-version-codes file is malformed: {path}") from exc
    return {
        "packageName": str(payload.get("packageName", "")),
        "fetchedAtUtc": str(payload.get("fetchedAtUtc", "")),
        "usedVersionCodes": sorted(set(codes)),
        "tracks": payload.get("tracks", {}),
        "apkVersionCodes": payload.get("apkVersionCodes", []),
    }


def read_certificate_status(path: Path | None) -> dict[str, object]:
    if path is None or not path.is_file():
        return {"status": "notChecked"}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except ValueError as exc:
        raise ValueError(f"certificate evidence file is malformed: {path}") from exc
    matches = bool(payload.get("matches"))
    return {
        "status": "matched" if matches else "mismatched",
        "expectedSha256": payload.get("expectedSha256"),
        "actualSha256": payload.get("actualSha256"),
        "matches": matches,
    }


def evaluate(
    used_codes: list[int],
    current_code: int,
    certificate: dict[str, object] | None = None,
) -> dict[str, object]:
    used = sorted(set(used_codes))
    next_free = (max(used) + 1) if used else 1
    version_available = current_code not in used
    certificate = certificate or {"status": "notChecked"}
    certificate_mismatched = certificate.get("status") == "mismatched"

    errors: list[str] = []
    if not version_available:
        errors.append(
            f"versionCode {current_code} is already used on Google Play; "
            f"use {next_free} instead (bump pubspec.yaml)"
        )
    if certificate_mismatched:
        errors.append("upload keystore certificate does not match ANDROID_UPLOAD_CERT_SHA256")

    result = "PASS" if not errors else "BLOCKED"
    next_actions: list[str] = []
    if not version_available:
        next_actions.append(f"Bump pubspec.yaml versionCode to {next_free} (or higher).")
    if certificate_mismatched:
        next_actions.append("Align the upload keystore with ANDROID_UPLOAD_CERT_SHA256.")

    return {
        "result": result,
        "usedVersionCodes": used,
        "pubspecVersionCode": current_code,
        "nextFreeVersionCode": next_free,
        "versionCodeAvailable": version_available,
        "certificate": certificate,
        "registeredCertificateNote": REGISTERED_CERTIFICATE_NOTE,
        "errors": errors,
        "nextActions": next_actions,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--used-codes", required=True, type=Path)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--certificate", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    try:
        used = read_used_codes(args.used_codes)
        current_code = read_pubspec_version_code(args.pubspec)
        certificate = (
            read_certificate_status(args.certificate) if args.certificate else None
        )
    except (OSError, ValueError) as error:
        print(f"::error::play_state_preflight: {error}", file=sys.stderr)
        return 2

    result = evaluate(
        used["usedVersionCodes"],
        current_code,
        certificate=certificate,
    )
    result["source"] = {
        "packageName": used["packageName"],
        "fetchedAtUtc": used["fetchedAtUtc"],
        "tracks": used["tracks"],
        "apkVersionCodes": used["apkVersionCodes"],
        "pubspec": str(args.pubspec),
        "usedCodesFile": str(args.used_codes),
    }
    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
