from __future__ import annotations

import unittest

from tool.enforce_android_release_signing import transform_groovy, transform_kts


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
        self.assertIn('throw GradleException', result)
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
        self.assertIn('throw new GradleException', result)
        self.assertNotIn('signingConfigs.debug', result)
        self.assertEqual(transform_groovy(result), result)


if __name__ == '__main__':
    unittest.main()
