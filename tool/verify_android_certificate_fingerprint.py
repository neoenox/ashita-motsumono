#!/usr/bin/env python3
"""Compare Android signing certificate SHA-256 fingerprints."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


_FINGERPRINT_PATTERN = re.compile(r"^[0-9a-f]{64}$")


def normalize_fingerprint(value: str) -> str:
    normalized = re.sub(r"[^0-9A-Fa-f]", "", value).lower()
    if not _FINGERPRINT_PATTERN.fullmatch(normalized):
        raise ValueError(
            "SHA-256 certificate fingerprint must contain exactly 64 hexadecimal digits"
        )
    return normalized


def compare_fingerprints(expected: str, actual: str) -> tuple[str, str, bool]:
    normalized_expected = normalize_fingerprint(expected)
    normalized_actual = normalize_fingerprint(actual)
    return normalized_expected, normalized_actual, normalized_expected == normalized_actual


def format_fingerprint(value: str) -> str:
    normalized = normalize_fingerprint(value)
    return ":".join(
        normalized[index : index + 2].upper()
        for index in range(0, len(normalized), 2)
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected", required=True)
    parser.add_argument("--actual", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    try:
        expected, actual, matches = compare_fingerprints(args.expected, args.actual)
    except ValueError as error:
        print(f"::error::{args.label}: {error}", file=sys.stderr)
        return 2

    payload = {
        "label": args.label,
        "expectedSha256": format_fingerprint(expected),
        "actualSha256": format_fingerprint(actual),
        "matches": matches,
    }
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    if not matches:
        print(
            f"::error::{args.label}: certificate fingerprint mismatch. "
            f"Expected {payload['expectedSha256']}, got {payload['actualSha256']}",
            file=sys.stderr,
        )
        return 1

    print(f"{args.label}: {payload['actualSha256']} (matched)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
