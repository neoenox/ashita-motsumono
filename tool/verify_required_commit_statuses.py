from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable


def latest_context_states(payload: dict[str, Any]) -> dict[str, str]:
    """Return the newest state for each commit-status context.

    GitHub's combined-status response returns `statuses` newest first. Keep the
    first occurrence so an older success cannot mask a newer pending/failure.
    """
    latest: dict[str, str] = {}
    statuses = payload.get("statuses", [])
    if not isinstance(statuses, list):
        raise ValueError("combined status payload must contain a statuses list")

    for status in statuses:
        if not isinstance(status, dict):
            continue
        context = status.get("context")
        state = status.get("state")
        if isinstance(context, str) and isinstance(state, str):
            latest.setdefault(context, state)
    return latest


def verify_required_statuses(
    payload: dict[str, Any], required_contexts: Iterable[str]
) -> list[str]:
    latest = latest_context_states(payload)
    problems: list[str] = []
    for context in required_contexts:
        state = latest.get(context)
        if state != "success":
            problems.append(f"{context}={state or 'missing'}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fail unless required GitHub commit-status contexts are successful."
    )
    parser.add_argument("status_json", type=Path)
    parser.add_argument("contexts", nargs="+")
    args = parser.parse_args()

    payload = json.loads(args.status_json.read_text(encoding="utf-8"))
    problems = verify_required_statuses(payload, args.contexts)
    if problems:
        print("Required exact-SHA CI is not successful: " + ", ".join(problems))
        return 1

    print("Exact-SHA CI gate passed: " + ", ".join(args.contexts))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
