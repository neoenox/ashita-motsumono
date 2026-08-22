#!/usr/bin/env python3
"""Validate release-candidate repository state without building or deploying.

The optional configuration check consumes boolean environment flags only, except the
keystore secret values that are compared byte-for-byte for drift detection. Secret
values are never printed.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import re
from typing import Iterable

REQUIRED_FILES = (
    "pubspec.yaml",
    "lib/src/app_version.g.dart",
    "docs/STORE_LISTING_JA.md",
    "docs/RELEASE_NOTES_V070_JA.md",
    "docs/PLAY_CONSOLE_SUBMISSION.md",
    "docs/ANDROID_RELEASE.md",
    "docs/RELEASE_EXECUTION_PLAN.md",
    "assets/store/icon-512.png",
    "assets/store/screenshots/01-home.png",
    "assets/store/screenshots/02-add-todo.png",
    "assets/store/screenshots/03-review-candidates.png",
    "assets/store/screenshots/04-todo-detail.png",
    "assets/store/screenshots/05-settings-supporter.png",
    ".github/workflows/ci.yml",
)

REQUIRED_SECRETS = (
    "KEYSTORE_STORE_PASSWORD",
    "KEYSTORE_KEY_PASSWORD",
    "KEYSTORE_KEY_ALIAS",
    "ADMOB_APP_ID",
    "ADMOB_BANNER_AD_UNIT_ID",
    "GEMINI_PROXY_URL",
)

# release-apk.yml / ci.yml use KEYSTORE_BASE64 while release-android.yml uses
# KEYSTORE_FILE_B64; at least one of the two must be configured.
KEYSTORE_SECRET_ALTERNATIVES = (
    "KEYSTORE_BASE64",
    "KEYSTORE_FILE_B64",
)

REQUIRED_VARIABLES = (
    "ANDROID_UPLOAD_CERT_SHA256",
    "IAP_REMOVE_ADS_PRODUCT_ID",
    "IAP_AI_ACCESS_PRODUCT_ID",
)

VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+\+\d+$")
PUBSPEC_VERSION_PATTERN = re.compile(r"^version:\s*([^\s#]+)", re.MULTILINE)
APP_VERSION_PATTERN = re.compile(r"const\s+appVersion\s*=\s*'([^']+)';")
SHORT_DESCRIPTION_HEADING = "## 短い説明（80文字以内）"


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _truthy(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes", "on"}


def _extract_version(pubspec_text: str) -> str:
    match = PUBSPEC_VERSION_PATTERN.search(pubspec_text)
    if match is None:
        raise ValueError("pubspec.yaml version was not found")
    return match.group(1)


def _extract_app_version(app_version_text: str) -> str:
    match = APP_VERSION_PATTERN.search(app_version_text)
    if match is None:
        raise ValueError("generated appVersion constant was not found")
    return match.group(1)


def _extract_markdown_paragraph(text: str, heading: str) -> str:
    lines = text.splitlines()
    try:
        start = lines.index(heading) + 1
    except ValueError as exc:
        raise ValueError(f"heading not found: {heading}") from exc

    paragraph: list[str] = []
    for line in lines[start:]:
        stripped = line.strip()
        if not stripped:
            if paragraph:
                break
            continue
        if stripped.startswith("## "):
            break
        paragraph.append(stripped)
    if not paragraph:
        raise ValueError(f"paragraph is empty after heading: {heading}")
    return " ".join(paragraph)


def _required_config_presence(
    names: Iterable[str], prefix: str, environment: dict[str, str]
) -> tuple[list[str], list[str]]:
    present: list[str] = []
    missing: list[str] = []
    for name in names:
        key = f"HAS_{prefix}_{name}"
        if _truthy(environment.get(key)):
            present.append(name)
        else:
            missing.append(name)
    return present, missing


def _keystore_secret_state(
    environment: dict[str, str]
) -> tuple[list[str], list[str]]:
    found: list[str] = []
    for name in KEYSTORE_SECRET_ALTERNATIVES:
        flagged = _truthy(environment.get(f"HAS_SECRET_{name}"))
        if flagged or (environment.get(name) or "").strip():
            found.append(name)

    errors: list[str] = []
    if not found:
        errors.append(
            "no keystore secret is configured; register at least one of "
            f"{', '.join(KEYSTORE_SECRET_ALTERNATIVES)}"
        )
    elif len(found) == len(KEYSTORE_SECRET_ALTERNATIVES):
        values = [environment.get(name) or "" for name in KEYSTORE_SECRET_ALTERNATIVES]
        if any(not value.strip() for value in values):
            errors.append(
                "both keystore secrets are configured but their values were not "
                "provided for drift verification"
            )
        else:
            decoded: list[bytes] = []
            for name, value in zip(KEYSTORE_SECRET_ALTERNATIVES, values):
                try:
                    decoded.append(base64.b64decode(value))
                except ValueError:
                    errors.append(f"keystore secret is not valid base64: {name}")
            if (
                len(decoded) == len(KEYSTORE_SECRET_ALTERNATIVES)
                and decoded[0] != decoded[1]
            ):
                errors.append(
                    "keystore secret drift detected: "
                    f"{KEYSTORE_SECRET_ALTERNATIVES[0]} and "
                    f"{KEYSTORE_SECRET_ALTERNATIVES[1]} decode to different bytes"
                )
    return found, errors


def evaluate(
    root: Path,
    *,
    expected_version_prefix: str | None = None,
    check_configuration: bool = False,
    environment: dict[str, str] | None = None,
) -> dict[str, object]:
    root = root.resolve()
    errors: list[str] = []
    missing_files: list[str] = []

    for relative in REQUIRED_FILES:
        path = root / relative
        if not path.is_file() or path.stat().st_size <= 0:
            missing_files.append(relative)
    if missing_files:
        errors.append("required release files are missing or empty")

    version = ""
    displayed_version = ""
    short_description = ""

    pubspec_path = root / "pubspec.yaml"
    app_version_path = root / "lib/src/app_version.g.dart"
    store_listing_path = root / "docs/STORE_LISTING_JA.md"
    workflow_path = root / ".github/workflows/ci.yml"

    if pubspec_path.is_file():
        try:
            version = _extract_version(_read_text(pubspec_path))
            if not VERSION_PATTERN.fullmatch(version):
                errors.append(f"release version has invalid format: {version}")
            if expected_version_prefix and not version.startswith(expected_version_prefix):
                errors.append(
                    "release version does not match expected prefix: "
                    f"expected {expected_version_prefix!r}, got {version!r}"
                )
        except (OSError, ValueError) as exc:
            errors.append(str(exc))

    if app_version_path.is_file():
        try:
            displayed_version = _extract_app_version(_read_text(app_version_path))
            if version and displayed_version != version:
                errors.append(
                    "displayed app version is out of sync: "
                    f"pubspec={version}, appVersion={displayed_version}"
                )
        except (OSError, ValueError) as exc:
            errors.append(str(exc))

    if store_listing_path.is_file():
        try:
            short_description = _extract_markdown_paragraph(
                _read_text(store_listing_path), SHORT_DESCRIPTION_HEADING
            )
            if len(short_description) > 80:
                errors.append(
                    "store short description exceeds 80 characters: "
                    f"{len(short_description)}"
                )
        except (OSError, ValueError) as exc:
            errors.append(str(exc))

    if workflow_path.is_file():
        workflow = _read_text(workflow_path)
        if "workflow_dispatch:" not in workflow:
            errors.append("ci.yml does not expose workflow_dispatch")
        for name in (*REQUIRED_SECRETS, *REQUIRED_VARIABLES):
            if name not in workflow:
                errors.append(f"ci.yml does not reference required release setting: {name}")

    configuration: dict[str, object]
    if check_configuration:
        env = dict(os.environ if environment is None else environment)
        present_secrets, missing_secrets = _required_config_presence(
            REQUIRED_SECRETS, "SECRET", env
        )
        present_variables, missing_variables = _required_config_presence(
            REQUIRED_VARIABLES, "VARIABLE", env
        )
        keystore_found_names, keystore_errors = _keystore_secret_state(env)
        configuration = {
            "result": (
                "PASS"
                if not missing_secrets
                and not missing_variables
                and not keystore_errors
                else "BLOCKED"
            ),
            "presentSecretNames": present_secrets,
            "missingSecretNames": missing_secrets,
            "presentVariableNames": present_variables,
            "missingVariableNames": missing_variables,
            "foundKeystoreSecretNames": keystore_found_names,
            "keystoreSecretErrors": keystore_errors,
        }
    else:
        configuration = {
            "result": "SKIPPED",
            "presentSecretNames": [],
            "missingSecretNames": [],
            "presentVariableNames": [],
            "missingVariableNames": [],
            "foundKeystoreSecretNames": [],
            "keystoreSecretErrors": [],
        }

    static_result = "PASS" if not errors else "BLOCKED"
    overall_result = (
        "PASS"
        if static_result == "PASS" and configuration["result"] in {"PASS", "SKIPPED"}
        else "BLOCKED"
    )

    next_actions: list[str] = []
    if errors:
        next_actions.append("Fix repository release-candidate invariants.")
    if configuration["result"] == "BLOCKED":
        next_actions.append("Register the missing GitHub Secrets and Repository Variables.")
    if configuration["keystoreSecretErrors"]:
        next_actions.append(
            "Reconcile the keystore secrets so at least one name is configured with matching bytes."
        )
    if overall_result == "PASS" and check_configuration:
        next_actions.append("Proceed to Issue #60 evidence; do not create a formal release yet.")
    elif overall_result == "PASS":
        next_actions.append("Run this preflight manually on master to inspect configuration presence.")

    return {
        "result": overall_result,
        "static": {
            "result": static_result,
            "errors": errors,
            "missingFiles": missing_files,
            "version": version,
            "displayedVersion": displayed_version,
            "shortDescription": short_description,
            "shortDescriptionLength": len(short_description),
        },
        "configuration": configuration,
        "nextActions": next_actions,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--expected-version-prefix")
    parser.add_argument("--check-configuration", action="store_true")
    args = parser.parse_args()

    result = evaluate(
        args.root,
        expected_version_prefix=args.expected_version_prefix,
        check_configuration=args.check_configuration,
    )
    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
