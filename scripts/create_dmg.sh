#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_PATH="$DIST_DIR/Mac AC Guard.app"
DMG_PATH="$DIST_DIR/MacACGuard.dmg"

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "Error: hdiutil is unavailable. DMG packaging requires macOS." >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: $APP_PATH is missing. Run ./scripts/package_app.sh first." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/MacACGuardDMG.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

echo "Creating MacACGuard.dmg..."
hdiutil create \
  -volname "Mac AC Guard" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created: $DMG_PATH"
