from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/ci.yml'
RELEASE_CONFIG = ROOT / 'tool/configure_android_release.sh'


class ReleaseWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding='utf-8')
        cls.release_config = RELEASE_CONFIG.read_text(encoding='utf-8')

    def test_flutter_sdk_is_pinned(self) -> None:
        self.assertEqual(self.workflow.count("flutter-version: '3.38.1'"), 2)

    def test_upload_keystore_certificate_is_verified_before_builds(self) -> None:
        verify = self.workflow.index('- name: Verify upload keystore certificate')
        apk_build = self.workflow.index('- name: Build release APK (signed)')
        aab_build = self.workflow.index(
            '- name: Build release AAB (signed, for Play Console submission)'
        )

        self.assertLess(verify, apk_build)
        self.assertLess(verify, aab_build)
        self.assertIn(
            'ANDROID_UPLOAD_CERT_SHA256: ${{ vars.ANDROID_UPLOAD_CERT_SHA256 }}',
            self.workflow,
        )
        self.assertIn('ANDROID_UPLOAD_CERT_SHA256 variable', self.workflow)
        self.assertIn('keytool -exportcert', self.workflow)
        self.assertIn('upload-keystore-certificate.json', self.workflow)

    def test_apk_is_verified_before_upload(self) -> None:
        build = self.workflow.index('- name: Build release APK (signed)')
        verify = self.workflow.index('- name: Verify signed APK')
        upload = self.workflow.index('- name: Upload signed APK artifact')

        self.assertLess(build, verify)
        self.assertLess(verify, upload)
        self.assertIn('verify --verbose --print-certs "$apk"', self.workflow)
        self.assertIn('certificate SHA-256 digest:', self.workflow)
        self.assertIn('--label "signed APK"', self.workflow)
        self.assertIn('apk-certificate.json', self.workflow)
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
        self.assertIn('keytool -printcert -jarfile "$aab"', self.workflow)
        self.assertIn('--label "signed AAB"', self.workflow)
        self.assertIn('aab-certificate.json', self.workflow)
        self.assertIn('AAB_SHA256SUMS', self.workflow)

    def test_release_manifest_is_generated_after_all_verification(self) -> None:
        apk_verify = self.workflow.index('- name: Verify signed APK')
        aab_verify = self.workflow.index('- name: Verify signed AAB')
        generate = self.workflow.index('- name: Generate release manifest')
        apk_upload = self.workflow.index('- name: Upload signed APK artifact')
        aab_upload = self.workflow.index('- name: Upload signed AAB artifact')
        evidence_upload = self.workflow.index('- name: Upload release evidence artifact')

        self.assertLess(apk_verify, generate)
        self.assertLess(aab_verify, generate)
        self.assertLess(generate, apk_upload)
        self.assertLess(generate, aab_upload)
        self.assertLess(generate, evidence_upload)
        self.assertIn('tool/generate_release_manifest.py', self.workflow)
        self.assertEqual(
            self.workflow.count('build/release-verification/release-manifest.json'),
            3,
        )
        self.assertIn('name: ashita-motsumono-release-evidence', self.workflow)

    def test_certificate_evidence_is_in_release_artifacts(self) -> None:
        self.assertEqual(self.workflow.count('upload-keystore-certificate.json'), 4)
        self.assertIn(
            'build/release-verification/apk-certificate.json',
            self.workflow,
        )
        self.assertIn(
            'build/release-verification/aab-certificate.json',
            self.workflow,
        )
        self.assertIn(
            'build/release-verification/aab-signer-certificate.txt',
            self.workflow,
        )

    def test_both_iap_product_ids_are_required_and_forwarded(self) -> None:
        self.assertIn(
            'IAP_REMOVE_ADS_PRODUCT_ID: ${{ vars.IAP_REMOVE_ADS_PRODUCT_ID }}',
            self.workflow,
        )
        self.assertIn(
            'IAP_AI_ACCESS_PRODUCT_ID: ${{ vars.IAP_AI_ACCESS_PRODUCT_ID }}',
            self.workflow,
        )
        self.assertIn('IAP_REMOVE_ADS_PRODUCT_ID variable', self.workflow)
        self.assertIn('IAP_AI_ACCESS_PRODUCT_ID variable', self.workflow)
        self.assertEqual(
            self.workflow.count(
                '--dart-define=IAP_REMOVE_ADS_PRODUCT_ID=${IAP_REMOVE_ADS_PRODUCT_ID}'
            ),
            2,
        )
        self.assertEqual(
            self.workflow.count(
                '--dart-define=IAP_AI_ACCESS_PRODUCT_ID=${IAP_AI_ACCESS_PRODUCT_ID}'
            ),
            2,
        )
        self.assertIn('--iap-ai-product-id "$IAP_AI_ACCESS_PRODUCT_ID"', self.workflow)

    def test_regenerated_platform_preserves_privacy_configuration(self) -> None:
        release = self.release_config.index('configure_android_release.py')
        privacy = self.release_config.index('configure_android_privacy.py')
        display_name = self.release_config.index('configure_platform_display_name.py')
        signing = self.release_config.index('enforce_android_release_signing.py')

        self.assertLess(release, privacy)
        self.assertLess(privacy, display_name)
        self.assertLess(display_name, signing)


if __name__ == '__main__':
    unittest.main()
