#!/usr/bin/env python3
"""Pick the next free versionCode from Google Play at version-bump time.

Abolishes guessing build numbers (e.g. 0.7.0+5) at release bumps. The used
version-code list is fetched from the Play Developer API by the fastlane
`play_preflight` lane using the service account; this tool reads that list,
decides whether the current pubspec versionCode is still usable, and picks
the next free number (max used + 1, or current if already usable).

Typical flow:

    bundle exec fastlane android play_preflight
    python3 tool/bump_app_version.py --write
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

if not __package__:
    # Allow running as `python3 tool/bump_app_version.py` from the repo root
    # while still being importable as `tool.bump_app_version` in unit tests.
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tool.play_state_preflight import read_used_codes
from tool.sync_app_version import GENERATED as GENERATED_PATH
from tool.sync_app_version import render as render_app_version

PUBSPEC_VERSION_PATTERN = re.compile(r"^version:\s*([^\s#]+)", re.MULTILINE)


def read_current_version(pubspec: Path) -> tuple[str, int]:
    match = PUBSPEC_VERSION_PATTERN.search(pubspec.read_text(encoding="utf-8"))
    if match is None:
        raise ValueError(f"pubspec version was not found: {pubspec}")
    name, separator, code = match.group(1).partition("+")
    if not separator or not code.isdigit():
        raise ValueError(
            f"pubspec version must use <name>+<build-number>: {match.group(1)!r}"
        )
    return name, int(code)


def target_version_code(current_code: int, used_codes: list[int]) -> tuple[int, bool]:
    """Return (target versionCode, whether a bump is needed).

    A code is usable when it was never used and is greater than every code
    Play has ever used (superseded codes stay non-reusable). Otherwise the
    next free code is max(max used, current) + 1, which is strictly greater
    than both the Play history and the current value.
    """
    used = sorted(set(used_codes))
    max_used = max(used) if used else 0
    usable = current_code not in used and current_code > max_used
    if usable:
        return current_code, False
    return max(max_used, current_code) + 1, True


def write_version(pubspec: Path, generated: Path, version: str) -> None:
    text = pubspec.read_text(encoding="utf-8")
    updated, count = PUBSPEC_VERSION_PATTERN.subn(f"version: {version}", text, count=1)
    if count != 1:
        raise ValueError(f"could not rewrite version in {pubspec}")
    pubspec.write_text(updated, encoding="utf-8")
    generated.write_text(render_app_version(version), encoding="utf-8")


def build_report(
    *,
    name: str,
    current_name: str,
    current_code: int,
    used_codes: list[int],
    target_code: int,
    bumped: bool,
    applied: bool,
) -> dict[str, object]:
    used = sorted(set(used_codes))
    max_used = max(used) if used else 0
    report = {
        "result": "BUMPED" if bumped else "NO_CHANGE",
        "versionName": name,
        "currentVersion": f"{current_name}+{current_code}",
        "currentVersionCode": current_code,
        "usedVersionCodes": used,
        "maxUsedVersionCode": max_used,
        "nextFreeVersionCode": max_used + 1,
        "targetVersionCode": target_code,
        "targetVersion": f"{name}+{target_code}",
        "applied": applied,
        "message": "",
        "suggestedCommit": "",
    }
    if bumped:
        report["message"] = (
            f"versionCode {current_code} は Play で使用済みまたは利用不可。"
            f"次空き {target_code}（{name}+{target_code}）へ採番する。"
        )
        report["suggestedCommit"] = (
            f"fix(release): アプリバージョンを {name}+{target_code} に引き上げ "
            f"(versionCode {target_code})\n\n"
            f"Play 状態 preflight が「使用済み = {', '.join(map(str, used)) or '(なし)'}"
            f"・次空き = {target_code}」を実 API から確認した。"
        )
    else:
        report["message"] = (
            f"{name}+{current_code} は Play で未使用のため変更不要。"
        )
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--used-codes", required=True, type=Path)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--name", help="override the version name (default: keep current)")
    parser.add_argument("--write", action="store_true", help="apply the bump to files")
    parser.add_argument("--output", type=Path, help="write the report JSON here")
    args = parser.parse_args()

    try:
        used_codes = read_used_codes(args.used_codes)["usedVersionCodes"]
        current_name, current_code = read_current_version(args.pubspec)
    except (OSError, ValueError) as error:
        print(f"::error::bump_app_version: {error}", file=sys.stderr)
        return 2

    name = args.name or current_name
    target_code, bumped = target_version_code(current_code, used_codes)
    applied = False
    if args.write:
        write_version(args.pubspec, GENERATED_PATH, f"{name}+{target_code}")
        applied = True

    report = build_report(
        name=name,
        current_name=current_name,
        current_code=current_code,
        used_codes=used_codes,
        target_code=target_code,
        bumped=bumped,
        applied=applied,
    )
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
