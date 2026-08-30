from __future__ import annotations

import unittest

from tool.verify_required_commit_statuses import verify_required_statuses


class VerifyRequiredCommitStatusesTest(unittest.TestCase):
    def test_all_required_contexts_must_be_successful(self) -> None:
        payload = {
            "statuses": [
                {"context": "worker-ci-master", "state": "success"},
                {"context": "flutter-ci-master", "state": "success"},
            ]
        }
        self.assertEqual(
            verify_required_statuses(
                payload, ("flutter-ci-master", "worker-ci-master")
            ),
            [],
        )

    def test_missing_pending_and_failure_are_blocking(self) -> None:
        payload = {
            "statuses": [
                {"context": "flutter-ci-master", "state": "pending"},
                {"context": "worker-ci-master", "state": "failure"},
            ]
        }
        self.assertEqual(
            verify_required_statuses(
                payload,
                ("flutter-ci-master", "worker-ci-master", "security-ci-master"),
            ),
            [
                "flutter-ci-master=pending",
                "worker-ci-master=failure",
                "security-ci-master=missing",
            ],
        )

    def test_newer_failure_cannot_be_masked_by_older_success(self) -> None:
        payload = {
            "statuses": [
                {"context": "flutter-ci-master", "state": "failure"},
                {"context": "flutter-ci-master", "state": "success"},
            ]
        }
        self.assertEqual(
            verify_required_statuses(payload, ("flutter-ci-master",)),
            ["flutter-ci-master=failure"],
        )


if __name__ == "__main__":
    unittest.main()
