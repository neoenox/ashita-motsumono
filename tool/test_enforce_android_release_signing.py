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
from tool.enforce_android_release_signing import transform_groovy, transform_kts


ROOT = Path(__file__).resolve().parents[1]
CONFIGURE_RELEASE = ROOT / 'tool/configure_android_release.sh'


class ReleaseSigningTransformTest(unittest.TestCase):
    def test_kts_adds_release_signing_and_removes_debug_fallback(self) -> None:
        source = '''plugins { id("com.android.application") }
android {
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
'''

        result = transform_kts(source)

        self.assertIn('create("release")', result)
        self.assertIn('Play release signing enforcement: begin', result)
        self.assertIn('signingConfig = releaseSigning', result)
        self.assertNotIn('startParameter', result)
        self.assertNotIn('getByName("debug")', result)
        self.assertEqual(transform_kts(result), result)

    def test_kts_removes_existing_multiline_debug_fallback(self) -> None:
        source = '''android {
    signingConfigs {
        create("release") {
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")?.takeIf { it.storeFile != null }
                ?: signingConfigs.getByName("debug")
        }
    }
}
'''

        result = transform_kts(source)

        self.assertNotIn('getByName("debug")', result)
        self.assertEqual(result.count('Play release signing enforcement: begin'), 1)

    def test_kts_parser_ignores_braces_inside_triple_quoted_strings(self) -> None:
        source = '''android {
    val sample = """
        text with a single " quote and braces { }
    """
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
'''

        result = transform_kts(source)

        self.assertIn('text with a single " quote and braces { }', result)
        self.assertNotIn('getByName("debug")', result)

    def test_groovy_adds_release_signing_and_removes_debug_fallback(self) -> None:
        source = '''android {
    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
'''

        result = transform_groovy(source)

        self.assertIn('signingConfigs {', result)
        self.assertIn('Play release signing enforcement: begin', result)
        self.assertIn('signingConfig releaseSigning', result)
        self.assertNotIn('startParameter', result)
        self.assertNotIn('signingConfigs.debug', result)
        self.assertEqual(transform_groovy(result), result)


class PlatformDisplayNameTest(unittest.TestCase):
    def test_release_configuration_applies_platform_display_name(self) -> None:
        script = CONFIGURE_RELEASE.read_text(encoding='utf-8')
        display_name = script.index('configure_platform_display_name.py')
        signing = script.index('enforce_android_release_signing.py')

        self.assertLess(display_name, signing)

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
        assert application is not None
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
