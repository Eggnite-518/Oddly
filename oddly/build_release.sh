#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

flutter build apk --release

VERSION=$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)
APK_DIR="build/app/outputs/flutter-apk"
SRC="$APK_DIR/app-release.apk"
DEST="$APK_DIR/Oddly-v${VERSION}.apk"

if [[ ! -f "$SRC" ]]; then
  echo "Error: APK not found at $SRC" >&2
  exit 1
fi

mv "$SRC" "$DEST"
echo "✓ Built $DEST"
