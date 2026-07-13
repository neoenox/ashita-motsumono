from __future__ import annotations

from pathlib import Path
import plistlib
import unittest
import xml.etree.ElementTree as ET

from tool.configure_platform_display_name import (
    ANDROID_NS,
    APP_DISPLAY_NAME,
    transform_android_manifest,
    transform_ios_info_plist,
)


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/ci.yml'
CONFIGURE_RELEASE = ROOT / 'tool/configure_android_release.sh'


class ReleaseWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding='utf-8')

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

    def test_certificate_evidence_is_in_both_artifacts(self) -> None:
        self.assertEqual(self.workflow.count('upload-keystore-certificate.json'), 3)
        self.assertIn('build/release-verification/apk-certificate.json', self.workflow)
        self.assertIn('build/release-verification/aab-certificate.json', self.workflow)
        self.assertIn(
            'build/release-verification/aab-signer-certificate.txt',
            self.workflow,
        )

    def test_iap_product_id_uses_repository_variable_with_fallback(self) -> None:
        self.assertIn(
            "IAP_REMOVE_ADS_PRODUCT_ID: ${{ vars.IAP_REMOVE_ADS_PRODUCT_ID || 'remove_ads' }}",
            self.workflow,
        )
        self.assertIn(
            '--dart-define=IAP_REMOVE_ADS_PRODUCT_ID=${IAP_REMOVE_ADS_PRODUCT_ID}',
            self.workflow,
        )

    def test_release_configuration_applies_platform_display_name(self) -> None:
        script = CONFIGURE_RELEASE.read_text(encoding='utf-8')
        display_name = script.index('configure_platform_display_name.py')
        signing = script.index('enforce_android_release_signing.py')

        self.assertLess(display_name, signing)


class PlatformDisplayNameTest(unittest.TestCase):
    def test_android_manifest_label_is_overwritten_and_idempotent(self) -> None:
        manifest = '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="old name">
        <activity android:name=".MainActivity" />
    </application>
</manifest>
'''

        updated = transform_android_manifest(manifest)
        root = ET.fromstring(updated)
        application = root.find('application')

        self.assertIsNotNone(application)
        self.assertEqual(
            application.get(f'{{{ANDROID_NS}}}label'),
            APP_DISPLAY_NAME,
        )
        self.assertEqual(transform_android_manifest(updated), updated)

    def test_ios_display_name_is_overwritten_and_idempotent(self) -> None:
        info_plist = plistlib.dumps(
            {
                'CFBundleDisplayName': 'old name',
                'CFBundleName': 'old name',
                'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
            },
            fmt=plistlib.FMT_XML,
            sort_keys=False,
        )

        updated = transform_ios_info_plist(info_plist)
        values = plistlib.loads(updated)

        self.assertEqual(values['CFBundleDisplayName'], APP_DISPLAY_NAME)
        self.assertEqual(values['CFBundleName'], APP_DISPLAY_NAME)
        self.assertEqual(transform_ios_info_plist(updated), updated)

    def test_public_name_is_consistent_in_release_sources(self) -> None:
        paths = (
            ROOT / 'README.md',
            ROOT / 'android/app/src/main/AndroidManifest.xml',
            ROOT / 'lib/main.dart',
            ROOT / 'docs/STORE_LISTING_JA.md',
            ROOT / 'docs/PLAY_CONSOLE_SUBMISSION.md',
        )

        for path in paths:
            with self.subTest(path=path):
                text = path.read_text(encoding='utf-8')
                self.assertIn(APP_DISPLAY_NAME, text)
                self.assertNotIn('あした持つもの', text)


if __name__ == '__main__':
    unittest.main()
