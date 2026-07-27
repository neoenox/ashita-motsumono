#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d)"
cp -R lib test docs README.md pubspec.yaml pubspec.lock analysis_options.yaml "$TMP_DIR"/

NATIVE_FILES=(
  "android/app/src/main/AndroidManifest.xml"
  "android/app/src/main/kotlin/com/ashita_motsumono/MainActivity.kt"
)
for native_file in "${NATIVE_FILES[@]}"; do
  if [[ -f "$native_file" ]]; then
    mkdir -p "$TMP_DIR/$(dirname "$native_file")"
    cp "$native_file" "$TMP_DIR/$native_file"
  fi
done

flutter create . --project-name ashita_motsumono --platforms=android,ios

rm -rf lib test docs
cp -R "$TMP_DIR/lib" "$ROOT/lib"
cp -R "$TMP_DIR/test" "$ROOT/test"
cp -R "$TMP_DIR/docs" "$ROOT/docs"
cp "$TMP_DIR/README.md" "$ROOT/README.md"
cp "$TMP_DIR/pubspec.yaml" "$ROOT/pubspec.yaml"
cp "$TMP_DIR/pubspec.lock" "$ROOT/pubspec.lock"
cp "$TMP_DIR/analysis_options.yaml" "$ROOT/analysis_options.yaml"

for native_file in "${NATIVE_FILES[@]}"; do
  if [[ -f "$TMP_DIR/$native_file" ]]; then
    mkdir -p "$(dirname "$native_file")"
    cp "$TMP_DIR/$native_file" "$native_file"
  fi
done
rm -rf "$TMP_DIR"

bash tool/configure_android_release.sh

echo "Platform files created and Android OCR/notification/share settings applied. Next: flutter pub get"
