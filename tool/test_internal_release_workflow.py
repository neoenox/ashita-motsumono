from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/release-android.yml'
READINESS_WORKFLOW = ROOT / '.github/workflows/release-readiness-preflight.yml'
FASTFILE = ROOT / 'fastlane/Fastfile'
APPFILE = ROOT / 'fastlane/Appfile'
GEMFILE = ROOT / 'Gemfile'
GUIDE = ROOT / 'docs/PLAY_INTERNAL_RELEASE.md'


class InternalReleaseWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding='utf-8')
        cls.readiness = READINESS_WORKFLOW.read_text(encoding='utf-8')
        cls.fastfile = FASTFILE.read_text(encoding='utf-8')
        cls.appfile = APPFILE.read_text(encoding='utf-8')
        cls.gemfile = GEMFILE.read_text(encoding='utf-8')
        cls.guide = GUIDE.read_text(encoding='utf-8')

    def test_release_is_limited_to_master_commits(self) -> None:
        self.assertIn('git merge-base --is-ancestor "$GITHUB_SHA" origin/master', self.workflow)
        self.assertIn('Internal releases must point to a commit already contained in master', self.workflow)

    def test_tag_must_match_pubspec_version_name(self) -> None:
        self.assertIn('expected_tag="v${pubspec_version}"', self.workflow)
        self.assertIn('Tag $GITHUB_REF_NAME does not match pubspec version', self.workflow)

    def test_service_account_is_required_and_written_outside_repository(self) -> None:
        self.assertIn('PLAY_SERVICE_ACCOUNT_JSON', self.workflow)
        self.assertIn('$RUNNER_TEMP/play-service-account.json', self.workflow)
        self.assertIn('python3 -m json.tool "$credential"', self.workflow)
        self.assertIn('rm -f "$PLAY_SERVICE_ACCOUNT_JSON_PATH"', self.workflow)

    def test_signed_aab_is_verified_before_upload(self) -> None:
        build = self.workflow.index('- name: Build signed release AAB')
        verify = self.workflow.index('- name: Verify signed AAB')
        credentials = self.workflow.index('- name: Validate Google Play API credential')
        upload = self.workflow.index('- name: Upload AAB to internal testing')
        self.assertLess(build, verify)
        self.assertLess(verify, credentials)
        self.assertLess(credentials, upload)
        self.assertIn('ANDROID_UPLOAD_CERT_SHA256', self.workflow)
        self.assertIn('jarsigner -verify -verbose -certs', self.workflow)

    def test_fastlane_is_pinned_and_internal_only(self) -> None:
        self.assertIn('gem "fastlane", "2.237.0"', self.gemfile)
        self.assertIn('package_name("com.ashita_motsumono")', self.appfile)
        self.assertIn('track: "internal"', self.fastfile)
        self.assertNotIn('track: "production"', self.fastfile)
        self.assertIn('skip_upload_metadata: true', self.fastfile)
        self.assertIn('skip_upload_changelogs: false', self.fastfile)

    def test_guide_uses_play_state_preflight_for_version_code(self) -> None:
        self.assertIn('play_preflight', self.guide)
        self.assertIn('使用済みversionCode', self.guide)
        self.assertIn('featureブランチから直接配布せず', self.guide)

    def test_play_preflight_runs_before_aab_build(self) -> None:
        cert = self.workflow.index('- name: Verify upload keystore certificate')
        preflight = self.workflow.index('- name: Play release preflight (used versionCode)')
        build = self.workflow.index('- name: Build signed release AAB')
        self.assertLess(cert, preflight)
        self.assertLess(preflight, build)
        self.assertIn('bundle exec fastlane android play_preflight', self.workflow)
        self.assertIn('tool/play_state_preflight.py', self.workflow)
        self.assertIn('--used-codes build/play-release/used-version-codes.json', self.workflow)
        self.assertIn('--certificate build/upload-keystore-certificate.json', self.workflow)
        self.assertIn('build/play-release/play-state-preflight.json', self.workflow)

    def test_play_preflight_evidence_is_uploaded(self) -> None:
        self.assertIn('build/play-release/used-version-codes.json', self.workflow)
        self.assertIn('build/play-release/play-state-preflight.json', self.workflow)

    def test_fastlane_play_preflight_fetches_used_version_codes(self) -> None:
        self.assertIn('lane :play_preflight', self.fastfile)
        self.assertIn('insert_edit', self.fastfile)
        self.assertIn('list_edit_tracks', self.fastfile)
        self.assertIn('list_edit_apks', self.fastfile)
        self.assertIn('used-version-codes.json', self.fastfile)

    def test_fastlane_paths_resolve_from_repo_root(self) -> None:
        # fastlane lanes run with CWD set to the Fastfile directory, so relative
        # paths must be resolved against the repository root, not the lane CWD.
        self.assertIn('def repo_root', self.fastfile)
        self.assertIn('File.expand_path("..", __dir__)', self.fastfile)
        self.assertIn('"build/play-release/used-version-codes.json",', self.fastfile)
        self.assertIn('repo_root,', self.fastfile)

    def test_readiness_workflow_has_play_state_preflight_job(self) -> None:
        self.assertIn('play-state-preflight:', self.readiness)
        self.assertIn('bundle exec fastlane android play_preflight', self.readiness)
        self.assertIn(
            '--used-codes build/play-release/used-version-codes.json',
            self.readiness,
        )
        self.assertIn('release-readiness-play-state-', self.readiness)


if __name__ == '__main__':
    unittest.main()
