from __future__ import annotations

import copy
import unittest

from tool.ocr_benchmark.summarize import (
    BenchmarkValidationError,
    build_summary,
    validate_payload,
)


def _document(index: int) -> dict[str, object]:
    return {
        "id": f"DOC-{index:03d}",
        "input_type": "printed",
        "page_count": 1,
        "ingest_success": True,
        "ocr_success": True,
        "ocr_empty": False,
        "candidate_count": 4,
        "correct_date_candidates": 1,
        "wrong_date_candidates": 0,
        "expected_date_count": 1,
        "correct_item_candidates": 3,
        "wrong_item_candidates": 0,
        "expected_item_count": 3,
        "unnecessary_candidates": 0,
        "missing_extractions": 0,
        "registered_without_edit": index <= 21,
        "manual_edit_then_registrable": True,
        "edit_count": 0 if index <= 21 else 1,
        "processing_time_seconds": float(index),
        "crash_or_freeze": False,
        "data_corruption": False,
        "manual_fallback_possible": True,
        "unconfirmed_wrong_due_date_auto_register": False,
    }


def _payload(documents: list[dict[str, object]]) -> dict[str, object]:
    return {
        "schema_version": 1,
        "dataset": {
            "source": "REPOSITORY_EXTERNAL_LOCAL_ONLY",
            "count": len(documents),
            "note": "原本とOCR全文はリポジトリ外で管理する。",
        },
        "documents": documents,
    }


class OcrBenchmarkSummaryTest(unittest.TestCase):
    def test_empty_dataset_is_blocked(self) -> None:
        summary = build_summary(_payload([]))

        self.assertEqual("BLOCKED", summary["verdict"]["status"])
        self.assertEqual(0, summary["metrics"]["document_count"])

    def test_thirty_qualifying_documents_pass(self) -> None:
        summary = build_summary(_payload([_document(index) for index in range(1, 31)]))

        self.assertEqual("PASS", summary["verdict"]["status"])
        self.assertEqual(30, summary["metrics"]["document_count"])
        self.assertEqual(0.7, summary["metrics"]["no_edit_registration_rate_printed"])
        self.assertEqual(29.0, summary["metrics"]["p95_processing_time_seconds"])

    def test_crash_produces_fail_after_minimum_evidence(self) -> None:
        documents = [_document(index) for index in range(1, 31)]
        documents[-1]["crash_or_freeze"] = True

        summary = build_summary(_payload(documents))

        self.assertEqual("FAIL", summary["verdict"]["status"])
        self.assertIn("crash_or_freeze was observed", summary["verdict"]["failures"])

    def test_sensitive_raw_text_key_is_rejected(self) -> None:
        document = _document(1)
        document["raw_text"] = "個人情報を含む可能性がある"

        with self.assertRaises(BenchmarkValidationError):
            validate_payload(_payload([document]))

    def test_dataset_count_must_match_documents(self) -> None:
        payload = _payload([_document(1)])
        payload = copy.deepcopy(payload)
        payload["dataset"]["count"] = 2

        with self.assertRaises(BenchmarkValidationError):
            validate_payload(payload)

    def test_ocr_failure_requires_manual_fallback(self) -> None:
        documents = [_document(index) for index in range(1, 31)]
        documents[-1].update(
            {
                "ocr_success": False,
                "ocr_empty": True,
                "manual_fallback_possible": False,
                "registered_without_edit": False,
                "edit_count": 1,
            }
        )

        summary = build_summary(_payload(documents))

        self.assertEqual("FAIL", summary["verdict"]["status"])
        self.assertIn(
            "OCR failure manual fallback rate is below target",
            summary["verdict"]["failures"],
        )


if __name__ == "__main__":
    unittest.main()
