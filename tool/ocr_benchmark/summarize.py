#!/usr/bin/env python3
"""Validate and summarize anonymized OCR benchmark records."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any


class BenchmarkValidationError(ValueError):
    """Raised when a benchmark payload is unsafe or structurally invalid."""


_ALLOWED_INPUT_TYPES = {
    "printed",
    "table",
    "pdf",
    "screenshot",
    "photo",
    "handwritten_mixed",
    "other",
}

_BOOLEAN_FIELDS = (
    "ingest_success",
    "ocr_success",
    "ocr_empty",
    "registered_without_edit",
    "manual_edit_then_registrable",
    "crash_or_freeze",
    "data_corruption",
    "manual_fallback_possible",
    "unconfirmed_wrong_due_date_auto_register",
)

_INTEGER_FIELDS = (
    "page_count",
    "candidate_count",
    "correct_date_candidates",
    "wrong_date_candidates",
    "expected_date_count",
    "correct_item_candidates",
    "wrong_item_candidates",
    "expected_item_count",
    "unnecessary_candidates",
    "missing_extractions",
    "edit_count",
)

_ROOT_FIELDS = frozenset({"schema_version", "dataset", "documents"})
_DATASET_FIELDS = frozenset({"source", "count"})
_DOCUMENT_FIELDS = frozenset(
    {"id", "input_type", "processing_time_seconds"}
    | set(_BOOLEAN_FIELDS)
    | set(_INTEGER_FIELDS)
)
_ANONYMOUS_ID_PATTERN = re.compile(r"^DOC-[0-9]{3,6}$")

_TARGETS = {
    "minimum_document_count": 30,
    "ingest_success_rate_min": 0.95,
    "crash_or_data_corruption_max": 0,
    "no_edit_registration_rate_min_printed": 0.70,
    "manual_edit_then_registrable_min": 0.95,
    "ocr_failure_manual_fallback_rate_min": 1.0,
    "unconfirmed_wrong_due_date_auto_register_max": 0,
}


def _require_mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise BenchmarkValidationError(f"{label} must be an object")
    if not all(isinstance(key, str) for key in value):
        raise BenchmarkValidationError(f"{label}: object keys must be strings")
    return value


def _require_exact_fields(
    value: dict[str, Any], allowed: frozenset[str], label: str
) -> None:
    actual = set(value)
    unknown = sorted(actual - allowed)
    missing = sorted(allowed - actual)
    if unknown:
        raise BenchmarkValidationError(
            f"{label} contains prohibited or unknown fields: {', '.join(unknown)}"
        )
    if missing:
        raise BenchmarkValidationError(
            f"{label} is missing required fields: {', '.join(missing)}"
        )


def _require_bool(document: dict[str, Any], field: str, label: str) -> bool:
    value = document[field]
    if type(value) is not bool:
        raise BenchmarkValidationError(f"{label}.{field} must be a boolean")
    return value


def _require_nonnegative_int(
    document: dict[str, Any], field: str, label: str, *, minimum: int = 0
) -> int:
    value = document[field]
    if type(value) is not int or value < minimum:
        raise BenchmarkValidationError(
            f"{label}.{field} must be an integer >= {minimum}"
        )
    return value


def _require_nonnegative_number(
    document: dict[str, Any], field: str, label: str
) -> float:
    value = document[field]
    if type(value) not in (int, float) or not math.isfinite(float(value)) or value < 0:
        raise BenchmarkValidationError(
            f"{label}.{field} must be a finite number >= 0"
        )
    return float(value)


def _validate_document_consistency(document: dict[str, Any], label: str) -> None:
    date_candidates = (
        document["correct_date_candidates"] + document["wrong_date_candidates"]
    )
    item_candidates = (
        document["correct_item_candidates"] + document["wrong_item_candidates"]
    )
    minimum_candidate_count = max(date_candidates, item_candidates)
    if document["candidate_count"] < minimum_candidate_count:
        raise BenchmarkValidationError(
            f"{label}.candidate_count is below the measured candidate counts"
        )

    minimum_unnecessary = max(
        document["wrong_date_candidates"], document["wrong_item_candidates"]
    )
    if document["unnecessary_candidates"] < minimum_unnecessary:
        raise BenchmarkValidationError(
            f"{label}.unnecessary_candidates is below the measured wrong candidates"
        )

    missing_dates = (
        document["expected_date_count"] - document["correct_date_candidates"]
    )
    missing_items = (
        document["expected_item_count"] - document["correct_item_candidates"]
    )
    minimum_missing = max(missing_dates, missing_items)
    if document["missing_extractions"] < minimum_missing:
        raise BenchmarkValidationError(
            f"{label}.missing_extractions is below the measured extraction gaps"
        )

    if not document["ingest_success"]:
        if document["ocr_success"]:
            raise BenchmarkValidationError(
                f"{label}: OCR cannot succeed when ingest_success is false"
            )
        if document["candidate_count"] != 0:
            raise BenchmarkValidationError(
                f"{label}: failed ingest cannot produce candidates"
            )
        if document["registered_without_edit"]:
            raise BenchmarkValidationError(
                f"{label}: failed ingest cannot be registered without edit"
            )
        if document["manual_edit_then_registrable"]:
            raise BenchmarkValidationError(
                f"{label}: failed ingest must use manual fallback, not candidate editing"
            )

    if document["ocr_success"] and document["ocr_empty"]:
        raise BenchmarkValidationError(
            f"{label}: ocr_success and ocr_empty cannot both be true"
        )
    if document["ocr_empty"] and document["candidate_count"] != 0:
        raise BenchmarkValidationError(f"{label}: empty OCR cannot produce candidates")
    if not document["ocr_success"] and document["registered_without_edit"]:
        raise BenchmarkValidationError(
            f"{label}: failed OCR cannot be registered without edit"
        )

    if document["registered_without_edit"]:
        if not document["manual_edit_then_registrable"]:
            raise BenchmarkValidationError(
                f"{label}: registered_without_edit implies registrable"
            )
        if document["edit_count"] != 0:
            raise BenchmarkValidationError(
                f"{label}: registered_without_edit requires edit_count=0"
            )


def validate_payload(payload: Any) -> list[dict[str, Any]]:
    """Validate a strict input schema, privacy boundary, and metric consistency."""

    root = _require_mapping(payload, "root")
    _require_exact_fields(root, _ROOT_FIELDS, "root")
    if root["schema_version"] != 1:
        raise BenchmarkValidationError("schema_version must be 1")

    dataset = _require_mapping(root["dataset"], "dataset")
    _require_exact_fields(dataset, _DATASET_FIELDS, "dataset")
    if dataset["source"] != "REPOSITORY_EXTERNAL_LOCAL_ONLY":
        raise BenchmarkValidationError(
            "dataset.source must be REPOSITORY_EXTERNAL_LOCAL_ONLY"
        )
    count = dataset["count"]
    if type(count) is not int or count < 0:
        raise BenchmarkValidationError("dataset.count must be an integer >= 0")

    documents = root["documents"]
    if not isinstance(documents, list):
        raise BenchmarkValidationError("documents must be an array")
    if count != len(documents):
        raise BenchmarkValidationError(
            f"dataset.count ({count}) does not match documents ({len(documents)})"
        )

    seen_ids: set[str] = set()
    validated: list[dict[str, Any]] = []
    for index, raw_document in enumerate(documents):
        label = f"documents[{index}]"
        document = _require_mapping(raw_document, label)
        _require_exact_fields(document, _DOCUMENT_FIELDS, label)

        document_id = document["id"]
        if not isinstance(document_id, str) or not _ANONYMOUS_ID_PATTERN.fullmatch(
            document_id
        ):
            raise BenchmarkValidationError(
                f"{label}.id must match DOC- followed by 3 to 6 digits"
            )
        if document_id in seen_ids:
            raise BenchmarkValidationError(f"{label}.id is duplicated: {document_id}")
        seen_ids.add(document_id)

        input_type = document["input_type"]
        if input_type not in _ALLOWED_INPUT_TYPES:
            allowed = ", ".join(sorted(_ALLOWED_INPUT_TYPES))
            raise BenchmarkValidationError(
                f"{label}.input_type must be one of: {allowed}"
            )

        for field in _BOOLEAN_FIELDS:
            _require_bool(document, field, label)
        for field in _INTEGER_FIELDS:
            minimum = 1 if field == "page_count" else 0
            _require_nonnegative_int(document, field, label, minimum=minimum)
        _require_nonnegative_number(document, "processing_time_seconds", label)

        if document["correct_date_candidates"] > document["expected_date_count"]:
            raise BenchmarkValidationError(
                f"{label}.correct_date_candidates exceeds expected_date_count"
            )
        if document["correct_item_candidates"] > document["expected_item_count"]:
            raise BenchmarkValidationError(
                f"{label}.correct_item_candidates exceeds expected_item_count"
            )

        _validate_document_consistency(document, label)
        validated.append(document)

    return validated


def _rate(numerator: int, denominator: int) -> float | None:
    if denominator == 0:
        return None
    return round(numerator / denominator, 6)


def _p95(values: list[float]) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, math.ceil(len(ordered) * 0.95) - 1)
    return round(ordered[index], 6)


def build_summary(payload: Any) -> dict[str, Any]:
    """Return calculated metrics and a conservative PASS/FAIL/BLOCKED verdict."""

    documents = validate_payload(payload)
    count = len(documents)
    printed = [doc for doc in documents if doc["input_type"] == "printed"]
    ocr_failures = [doc for doc in documents if not doc["ocr_success"]]

    correct_dates = sum(doc["correct_date_candidates"] for doc in documents)
    wrong_dates = sum(doc["wrong_date_candidates"] for doc in documents)
    expected_dates = sum(doc["expected_date_count"] for doc in documents)
    correct_items = sum(doc["correct_item_candidates"] for doc in documents)
    wrong_items = sum(doc["wrong_item_candidates"] for doc in documents)
    expected_items = sum(doc["expected_item_count"] for doc in documents)

    metrics = {
        "document_count": count,
        "printed_document_count": len(printed),
        "ingest_success_rate": _rate(
            sum(bool(doc["ingest_success"]) for doc in documents), count
        ),
        "ocr_empty_rate": _rate(
            sum(bool(doc["ocr_empty"]) for doc in documents), count
        ),
        "date_precision": _rate(correct_dates, correct_dates + wrong_dates),
        "date_recall": _rate(correct_dates, expected_dates),
        "item_precision": _rate(correct_items, correct_items + wrong_items),
        "item_recall": _rate(correct_items, expected_items),
        "no_edit_registration_rate": _rate(
            sum(bool(doc["registered_without_edit"]) for doc in documents), count
        ),
        "no_edit_registration_rate_printed": _rate(
            sum(bool(doc["registered_without_edit"]) for doc in printed), len(printed)
        ),
        "manual_edit_then_registrable_rate": _rate(
            sum(bool(doc["manual_edit_then_registrable"]) for doc in documents),
            count,
        ),
        "avg_edits_per_document": (
            round(sum(doc["edit_count"] for doc in documents) / count, 6)
            if count
            else None
        ),
        "p95_processing_time_seconds": _p95(
            [float(doc["processing_time_seconds"]) for doc in documents]
        ),
        "crash_rate": _rate(
            sum(bool(doc["crash_or_freeze"]) for doc in documents), count
        ),
        "data_corruption_count": sum(
            bool(doc["data_corruption"]) for doc in documents
        ),
        "ocr_failure_manual_fallback_rate": _rate(
            sum(bool(doc["manual_fallback_possible"]) for doc in ocr_failures),
            len(ocr_failures),
        ),
        "unconfirmed_wrong_due_date_auto_register_count": sum(
            bool(doc["unconfirmed_wrong_due_date_auto_register"])
            for doc in documents
        ),
    }

    blocked_reasons: list[str] = []
    failures: list[str] = []
    if count < _TARGETS["minimum_document_count"]:
        blocked_reasons.append(
            f"document_count={count} is below {_TARGETS['minimum_document_count']}"
        )
    if not printed:
        blocked_reasons.append("printed document evidence is missing")

    if count:
        if metrics["ingest_success_rate"] < _TARGETS["ingest_success_rate_min"]:
            failures.append("ingest_success_rate is below target")
        if metrics["crash_rate"] > _TARGETS["crash_or_data_corruption_max"]:
            failures.append("crash_or_freeze was observed")
        if metrics["data_corruption_count"] > _TARGETS["crash_or_data_corruption_max"]:
            failures.append("data corruption was observed")
        if (
            metrics["manual_edit_then_registrable_rate"]
            < _TARGETS["manual_edit_then_registrable_min"]
        ):
            failures.append("manual_edit_then_registrable_rate is below target")
        if (
            metrics["unconfirmed_wrong_due_date_auto_register_count"]
            > _TARGETS["unconfirmed_wrong_due_date_auto_register_max"]
        ):
            failures.append("an unconfirmed wrong due date was auto-registered")

    printed_rate = metrics["no_edit_registration_rate_printed"]
    if printed_rate is not None and printed_rate < _TARGETS[
        "no_edit_registration_rate_min_printed"
    ]:
        failures.append("printed no-edit registration rate is below target")

    fallback_rate = metrics["ocr_failure_manual_fallback_rate"]
    if fallback_rate is not None and fallback_rate < _TARGETS[
        "ocr_failure_manual_fallback_rate_min"
    ]:
        failures.append("OCR failure manual fallback rate is below target")

    if blocked_reasons:
        status = "BLOCKED"
    elif failures:
        status = "FAIL"
    else:
        status = "PASS"

    return {
        "schema_version": 1,
        "metrics": metrics,
        "targets": _TARGETS,
        "verdict": {
            "status": status,
            "blocked_reasons": blocked_reasons,
            "failures": failures,
            "note": (
                "p95 processing time is reported but has no automatic threshold; "
                "review it against actual usability."
            ),
        },
    }


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate and summarize anonymized OCR benchmark records."
    )
    parser.add_argument("input", type=Path, help="Benchmark JSON input")
    parser.add_argument("--output", type=Path, help="Write summary JSON")
    parser.add_argument(
        "--require-pass",
        action="store_true",
        help="Exit 3 unless the calculated verdict is PASS",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv or sys.argv[1:])
    try:
        payload = json.loads(args.input.read_text(encoding="utf-8"))
        summary = build_summary(payload)
    except (OSError, json.JSONDecodeError, BenchmarkValidationError) as error:
        print(f"OCR benchmark validation failed: {error}", file=sys.stderr)
        return 2

    rendered = json.dumps(summary, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")

    if args.require_pass and summary["verdict"]["status"] != "PASS":
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
