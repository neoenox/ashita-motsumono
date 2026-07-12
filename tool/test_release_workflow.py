from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/ci.yml'


class ReleaseWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding='utf-8')

    def test_apk_is_verified_before_upload(self) -> None:
        build = self.workflow.index('- name: Build release APK (signed)')
        verify = self.workflow.index('- name: Verify signed APK')
        upload = self.workflow.index('- name: Upload signed APK artifact')

        self.assertLess(build, verify)
        self.assertLess(verify, upload)
        self.assertIn('verify --verbose --print-certs "$apk"', self.workflow)
        self.assertIn('APK_SHA256SUMS', self.workflow)

    def test_aab_is_verified_before_upload(self) -> None:
        build = self.workflow.index(
            '- name: Build release AAB (signed, for Play Console submission)'
        )
        verify = self.workflow.index('- name: Verify signed AAB')
        upload = self.workflow.index('- name: Upload signed AAB artifact')

        self.assertLess(build, verify)
        self.assertLess(verify, upload)
        self.assertIn('jarsigner -verify -verbose -certs', self.workflow)
        self.assertIn('AAB_SHA256SUMS', self.workflow)

    def test_iap_product_id_uses_repository_variable_with_fallback(self) -> None:
        self.assertIn(
            "IAP_REMOVE_ADS_PRODUCT_ID: ${{ vars.IAP_REMOVE_ADS_PRODUCT_ID || 'remove_ads' }}",
            self.workflow,
        )
        self.assertIn(
            '--dart-define=IAP_REMOVE_ADS_PRODUCT_ID=${IAP_REMOVE_ADS_PRODUCT_ID}',
            self.workflow,
        )


if __name__ == '__main__':
    unittest.main()
