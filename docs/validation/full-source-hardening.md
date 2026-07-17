# Full source hardening validation

- Review branch: `agent/full-source-hardening`
- Pull request: #119
- Static code and contract changes: implemented
- Flutter SDK: pinned to `3.44.0` to satisfy the repository's Dart `>=3.12.0` constraint
- Temporary diagnostic workflows, evidence snapshots, triggers, and test-rewrite scripts: removed
- Standard validation path: `.github/workflows/ci.yml` only
- Cloudflare deployment, store purchase verification, real billing, refund, restore, and physical-device tests: external gates

The pull request is ready for review only after the standard CI succeeds on the latest head commit. This document does not classify external deployment or store/device checks as passed.
