from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
RELEASE = (ROOT / ".github/workflows/release-android.yml").read_text(encoding="utf-8")
WORKER = (ROOT / ".github/workflows/worker-ci.yml").read_text(encoding="utf-8")


class ExactShaReleaseGateWorkflowTest(unittest.TestCase):
    def test_internal_release_checks_both_ci_statuses_before_secrets(self) -> None:
        gate = RELEASE.index("- name: Verify exact-SHA CI health")
        secret_validation = RELEASE.index("- name: Validate required release configuration")
        signing_restore = RELEASE.index("- name: Restore Android signing key")

        self.assertLess(gate, secret_validation)
        self.assertLess(gate, signing_restore)
        self.assertIn("flutter-ci-master", RELEASE)
        self.assertIn("worker-ci-master", RELEASE)
        self.assertIn("tool/verify_required_commit_statuses.py", RELEASE)
        self.assertIn("statuses: read", RELEASE)

    def test_worker_ci_runs_for_every_master_sha_and_records_status(self) -> None:
        push_block = WORKER.split("push:", 1)[1].split("workflow_dispatch:", 1)[0]
        self.assertIn("- master", push_block)
        self.assertNotIn("paths:", push_block)
        self.assertIn("statuses: write", WORKER)
        self.assertIn('"context": "worker-ci-master"', WORKER)
        self.assertIn("needs: worker-quality", WORKER)


if __name__ == "__main__":
    unittest.main()
