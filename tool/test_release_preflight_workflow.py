from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/release-preflight.yml'


class ReleasePreflightWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding='utf-8')

    def test_initial_audit_is_limited_to_the_dedicated_branch(self) -> None:
        self.assertIn('workflow_dispatch:', self.workflow)
        self.assertIn('pull_request:', self.workflow)
        self.assertIn(
            "github.head_ref == 'agent/release-preflight-20260805'",
            self.workflow,
        )

    def test_preflight_does_not_contact_or_upload_to_google_play(self) -> None:
        forbidden = (
            'upload_to_play_store',
            'fastlane android internal',
            'validate_play_store_json_key',
            'PLAY_SERVICE_ACCOUNT_JSON',
            'curl ',
        )
        for value in forbidden:
            self.assertNotIn(value, self.workflow)
        self.assertIn('external_calls_performed', self.workflow)
        self.assertIn('play_upload_performed', self.workflow)

    def test_all_formal_release_configuration_is_required(self) -> None:
        required = (
            'KEYSTORE_BASE64',
            'KEYSTORE_STORE_PASSWORD',
            'KEYSTORE_KEY_PASSWORD',
            'KEYSTORE_KEY_ALIAS',
            'ADMOB_APP_ID',
            'ADMOB_BANNER_AD_UNIT_ID',
            'GEMINI_PROXY_URL',
            'IAP_REMOVE_ADS_PRODUCT_ID variable',
            'IAP_AI_ACCESS_PRODUCT_ID variable',
            'ANDROID_UPLOAD_CERT_SHA256 variable',
        )
        for value in required:
            self.assertIn(value, self.workflow)

    def test_configuration_formats_are_validated_without_printing_values(self) -> None:
        self.assertIn('admob_app_id_format', self.workflow)
        self.assertIn('admob_banner_id_format', self.workflow)
        self.assertIn('gemini_proxy_https', self.workflow)
        self.assertIn('iap_product_ids_distinct', self.workflow)
        self.assertIn('upload_certificate_sha256_format', self.workflow)
        self.assertNotIn("print(app_id)", self.workflow)
        self.assertNotIn("print(banner_id)", self.workflow)
        self.assertNotIn("print(gemini_url)", self.workflow)

    def test_upload_keystore_and_certificate_are_verified(self) -> None:
        restore = self.workflow.index(
            '- name: Restore and inspect Android upload keystore'
        )
        summary = self.workflow.index('- name: Write sanitized preflight summary')
        upload = self.workflow.index('- name: Upload sanitized preflight evidence')
        cleanup = self.workflow.index('- name: Remove temporary signing material')
        self.assertLess(restore, summary)
        self.assertLess(summary, upload)
        self.assertLess(upload, cleanup)
        self.assertIn('base64 --decode', self.workflow)
        self.assertIn('keytool -list', self.workflow)
        self.assertIn('keytool -exportcert', self.workflow)
        self.assertIn('verify_android_certificate_fingerprint.py', self.workflow)
        self.assertIn('upload-keystore-certificate.json', self.workflow)

    def test_artifact_contains_only_sanitized_evidence(self) -> None:
        self.assertIn('build/release-preflight/', self.workflow)
        self.assertIn('preflight-summary.json', self.workflow)
        self.assertNotIn('upload-keystore.jks\n          path:', self.workflow)
        self.assertIn('rm -f "$RUNNER_TEMP/upload-keystore.jks"', self.workflow)


if __name__ == '__main__':
    unittest.main()
