#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d android ]]; then
  echo "android/ was not found. Run tool/create_platforms.sh first." >&2
  exit 1
fi

# Delegate to the Python script (works on all platforms)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try python first, then python3
PYTHON_CMD=""
if command -v python &>/dev/null; then
  PYTHON_CMD="python"
elif command -v python3 &>/dev/null; then
  PYTHON_CMD="python3"
else
  echo "ERROR: Neither python nor python3 found. Install Python 3.9+." >&2
  exit 1
fi

exec "$PYTHON_CMD" "$SCRIPT_DIR/configure_android_release.py"