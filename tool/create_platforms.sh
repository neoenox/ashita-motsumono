#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d)"
cp -R lib test docs README.md pubspec.yaml pubspec.lock analysis_options.yaml "$TMP_DIR"/

flutter create . --project-name ashita_motsumono --platforms=android,ios

rm -rf lib test docs
cp -R "$TMP_DIR/lib" "$ROOT/lib"
cp -R "$TMP_DIR/test" "$ROOT/test"
cp -R "$TMP_DIR/docs" "$ROOT/docs"
cp "$TMP_DIR/README.md" "$ROOT/README.md"
cp "$TMP_DIR/pubspec.yaml" "$ROOT/pubspec.yaml"
cp "$TMP_DIR/pubspec.lock" "$ROOT/pubspec.lock"
cp "$TMP_DIR/analysis_options.yaml" "$ROOT/analysis_options.yaml"
rm -rf "$TMP_DIR"

bash tool/configure_android_release.sh

echo "Platform files created and Android OCR/notification settings applied. Next: flutter pub get"
