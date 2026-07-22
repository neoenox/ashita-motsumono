# Full source hardening validation

- Review branch: `agent/full-source-hardening`
- Pull request: #119
- Static code and contract changes: implemented
- Flutter SDK: pinned to `3.44.0` to satisfy the repository's Dart `>=3.12.0` constraint
- Temporary diagnostic workflows, evidence snapshots, triggers, and test-rewrite scripts: removed
- Standard validation path: `.github/workflows/ci.yml` only
- Latest-head CI: intentionally waived by the repository owner for review readiness; not classified as passed
- Cloudflare deployment, store purchase verification, real billing, refund, restore, and physical-device tests: external gates

The pull request may proceed to review without a successful latest-head CI result by explicit owner decision. This waiver is not evidence that the Flutter test suite, screenshot generation, release build, deployment, store, or physical-device checks passed.
