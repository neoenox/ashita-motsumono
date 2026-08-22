from __future__ import annotations

import base64
from pathlib import Path
import tempfile
import unittest

from tool.release_readiness_preflight import (
    KEYSTORE_SECRET_ALTERNATIVES,
    REQUIRED_FILES,
    REQUIRED_SECRETS,
    REQUIRED_VARIABLES,
    evaluate,
)


class ReleaseReadinessPreflightTest(unittest.TestCase):
    def _root(self) -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        for relative in REQUIRED_FILES:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            if relative == "pubspec.yaml":
                path.write_text("version: 0.7.0+3\n", encoding="utf-8")
            elif relative == "lib/src/app_version.g.dart":
                path.write_text("const appVersion = '0.7.0+3';\n", encoding="utf-8")
            elif relative == "docs/STORE_LISTING_JA.md":
                path.write_text(
                    "# Store\n\n"
                    "## 短い説明（80文字以内）\n\n"
                    "園・学校のプリントから持ち物をTodo化。\n",
                    encoding="utf-8",
                )
            elif relative == ".github/workflows/ci.yml":
                settings = "\n".join((*REQUIRED_SECRETS, *REQUIRED_VARIABLES))
                path.write_text(
                    f"name: CI\non:\n  workflow_dispatch:\n# {settings}\n",
                    encoding="utf-8",
                )
            else:
                path.write_bytes(b"fixture")
        return root

    def _configuration_environment(self, **overrides: str) -> dict[str, str]:
        environment = {
            **{f"HAS_SECRET_{name}": "true" for name in REQUIRED_SECRETS},
            **{f"HAS_VARIABLE_{name}": "1" for name in REQUIRED_VARIABLES},
        }
        environment.update(overrides)
        return environment

    def test_static_release_candidate_passes(self) -> None:
        result = evaluate(self._root(), expected_version_prefix="0.7.0+")
        self.assertEqual("PASS", result["result"])
        self.assertEqual("PASS", result["static"]["result"])
        self.assertEqual("SKIPPED", result["configuration"]["result"])

    def test_version_mismatch_is_blocked(self) -> None:
        root = self._root()
        (root / "lib/src/app_version.g.dart").write_text(
            "const appVersion = '0.7.0+2';\n", encoding="utf-8"
        )
        result = evaluate(root, expected_version_prefix="0.7.0+")
        self.assertEqual("BLOCKED", result["result"])
        self.assertTrue(
            any("out of sync" in error for error in result["static"]["errors"])
        )

    def test_wrong_release_prefix_is_blocked(self) -> None:
        result = evaluate(self._root(), expected_version_prefix="0.8.0+")
        self.assertEqual("BLOCKED", result["result"])
        self.assertTrue(
            any(
                "expected prefix" in error
                for error in result["static"]["errors"]
            )
        )

    def test_long_short_description_is_blocked(self) -> None:
        root = self._root()
        (root / "docs/STORE_LISTING_JA.md").write_text(
            "# Store\n\n## 短い説明（80文字以内）\n\n" + "あ" * 81 + "\n",
            encoding="utf-8",
        )
        result = evaluate(root)
        self.assertEqual("BLOCKED", result["result"])
        self.assertEqual(81, result["static"]["shortDescriptionLength"])

    def test_missing_configuration_reports_names_only(self) -> None:
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment={},
        )
        self.assertEqual("BLOCKED", result["result"])
        self.assertEqual(
            list(REQUIRED_SECRETS),
            result["configuration"]["missingSecretNames"],
        )
        self.assertEqual(
            list(REQUIRED_VARIABLES),
            result["configuration"]["missingVariableNames"],
        )
        self.assertEqual([], result["configuration"]["foundKeystoreSecretNames"])

    def test_no_keystore_secret_is_blocked(self) -> None:
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment=self._configuration_environment(),
        )
        self.assertEqual("BLOCKED", result["result"])
        self.assertEqual([], result["configuration"]["foundKeystoreSecretNames"])
        self.assertTrue(
            any(
                "at least one" in error
                for error in result["configuration"]["keystoreSecretErrors"]
            )
        )

    def test_only_keystore_base64_passes(self) -> None:
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment=self._configuration_environment(
                HAS_SECRET_KEYSTORE_BASE64="true"
            ),
        )
        self.assertEqual("PASS", result["result"])
        self.assertEqual(
            ["KEYSTORE_BASE64"],
            result["configuration"]["foundKeystoreSecretNames"],
        )

    def test_only_keystore_file_b64_passes(self) -> None:
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment=self._configuration_environment(
                HAS_SECRET_KEYSTORE_FILE_B64="true"
            ),
        )
        self.assertEqual("PASS", result["result"])
        self.assertEqual(
            ["KEYSTORE_FILE_B64"],
            result["configuration"]["foundKeystoreSecretNames"],
        )

    def test_matching_keystore_values_pass(self) -> None:
        encoded = base64.b64encode(b"keystore-bytes").decode("ascii")
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment=self._configuration_environment(
                HAS_SECRET_KEYSTORE_BASE64="true",
                HAS_SECRET_KEYSTORE_FILE_B64="true",
                KEYSTORE_BASE64=encoded,
                KEYSTORE_FILE_B64=encoded,
            ),
        )
        self.assertEqual("PASS", result["result"])
        self.assertEqual(
            list(KEYSTORE_SECRET_ALTERNATIVES),
            result["configuration"]["foundKeystoreSecretNames"],
        )

    def test_diverging_keystore_values_are_blocked(self) -> None:
        first = base64.b64encode(b"keystore-bytes").decode("ascii")
        second = base64.b64encode(b"different-bytes").decode("ascii")
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment=self._configuration_environment(
                HAS_SECRET_KEYSTORE_BASE64="true",
                HAS_SECRET_KEYSTORE_FILE_B64="true",
                KEYSTORE_BASE64=first,
                KEYSTORE_FILE_B64=second,
            ),
        )
        self.assertEqual("BLOCKED", result["result"])
        self.assertTrue(
            any(
                "different bytes" in error
                for error in result["configuration"]["keystoreSecretErrors"]
            )
        )

    def test_unverifiable_keystore_drift_is_blocked(self) -> None:
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment=self._configuration_environment(
                HAS_SECRET_KEYSTORE_BASE64="true",
                HAS_SECRET_KEYSTORE_FILE_B64="true",
            ),
        )
        self.assertEqual("BLOCKED", result["result"])
        self.assertTrue(
            any(
                "were not provided" in error
                for error in result["configuration"]["keystoreSecretErrors"]
            )
        )

    def test_complete_configuration_passes(self) -> None:
        environment = {
            **{f"HAS_SECRET_{name}": "true" for name in REQUIRED_SECRETS},
            "HAS_SECRET_KEYSTORE_BASE64": "true",
            **{f"HAS_VARIABLE_{name}": "1" for name in REQUIRED_VARIABLES},
        }
        result = evaluate(
            self._root(),
            expected_version_prefix="0.7.0+",
            check_configuration=True,
            environment=environment,
        )
        self.assertEqual("PASS", result["result"])
        self.assertEqual("PASS", result["configuration"]["result"])
        self.assertEqual([], result["configuration"]["missingSecretNames"])
        self.assertEqual([], result["configuration"]["missingVariableNames"])


if __name__ == "__main__":
    unittest.main()
