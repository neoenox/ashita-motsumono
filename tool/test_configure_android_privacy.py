from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from tool.configure_android_privacy import (
    BACKUP_RULES,
    DATA_EXTRACTION_RULES,
    configure,
    transform_manifest,
)


MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="Example"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
'''


class ConfigureAndroidPrivacyTest(unittest.TestCase):
    def test_transform_is_idempotent_and_sets_backup_attributes(self) -> None:
        first = transform_manifest(MANIFEST)
        second = transform_manifest(first)
        self.assertEqual(first, second)
        self.assertIn('android:allowBackup="false"', first)
        self.assertIn('android:fullBackupContent="@xml/backup_rules"', first)
        self.assertIn(
            'android:dataExtractionRules="@xml/data_extraction_rules"',
            first,
        )

    def test_configure_writes_both_rule_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / 'android/app/src/main/AndroidManifest.xml'
            manifest.parent.mkdir(parents=True)
            manifest.write_text(MANIFEST, encoding='utf-8')

            configure(root)

            xml_dir = root / 'android/app/src/main/res/xml'
            self.assertEqual(
                (xml_dir / 'backup_rules.xml').read_text(encoding='utf-8'),
                BACKUP_RULES,
            )
            self.assertEqual(
                (xml_dir / 'data_extraction_rules.xml').read_text(
                    encoding='utf-8'
                ),
                DATA_EXTRACTION_RULES,
            )


if __name__ == '__main__':
    unittest.main()
