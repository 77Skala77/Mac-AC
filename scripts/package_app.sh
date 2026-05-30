#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_PATH="$DIST_DIR/Mac AC Guard.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
EXECUTABLE_PATH="$MACOS_PATH/MacACGuard"

ARM64_BINARY="$ROOT_DIR/.build/arm64-apple-macosx/release/MacACGuard"
X86_64_BINARY="$ROOT_DIR/.build/x86_64-apple-macosx/release/MacACGuard"

echo "Building Mac AC Guard universal release app..."
echo "Root: $ROOT_DIR"

echo "Building arm64 release executable..."
swift build --package-path "$ROOT_DIR" -c release --arch arm64

echo "Building x86_64 release executable..."
swift build --package-path "$ROOT_DIR" -c release --arch x86_64

if [[ ! -f "$ARM64_BINARY" ]]; then
  echo "Error: arm64 binary not found at: $ARM64_BINARY" >&2
  echo "Searching for arm64 release binary..." >&2
  find "$ROOT_DIR/.build" -type f -path "*arm64*release/MacACGuard" -print >&2 || true
  exit 1
fi

if [[ ! -f "$X86_64_BINARY" ]]; then
  echo "Error: x86_64 binary not found at: $X86_64_BINARY" >&2
  echo "Searching for x86_64 release binary..." >&2
  find "$ROOT_DIR/.build" -type f -path "*x86_64*release/MacACGuard" -print >&2 || true
  exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"

echo "Creating universal binary..."
lipo -create \
  "$ARM64_BINARY" \
  "$X86_64_BINARY" \
  -output "$EXECUTABLE_PATH"

chmod +x "$EXECUTABLE_PATH"

echo "Universal binary info:"
file "$EXECUTABLE_PATH"
lipo -info "$EXECUTABLE_PATH"

LIPO_INFO="$(lipo -info "$EXECUTABLE_PATH")"
if [[ "$LIPO_INFO" != *"arm64"* ]]; then
  echo "Error: universal binary is missing arm64 architecture." >&2
  exit 1
fi

if [[ "$LIPO_INFO" != *"x86_64"* ]]; then
  echo "Error: universal binary is missing x86_64 architecture." >&2
  exit 1
fi

ARM64_BIN_DIR="$(dirname "$ARM64_BINARY")"
X86_64_BIN_DIR="$(dirname "$X86_64_BINARY")"

if [[ -d "$ARM64_BIN_DIR/MacACGuard_MacACGuard.bundle" ]]; then
  cp -R "$ARM64_BIN_DIR/MacACGuard_MacACGuard.bundle" "$RESOURCES_PATH/"
elif [[ -d "$X86_64_BIN_DIR/MacACGuard_MacACGuard.bundle" ]]; then
  cp -R "$X86_64_BIN_DIR/MacACGuard_MacACGuard.bundle" "$RESOURCES_PATH/"
fi

cp "$ROOT_DIR/README.md" "$RESOURCES_PATH/README.md"

cat > "$CONTENTS_PATH/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Mac AC Guard</string>
  <key>CFBundleExecutable</key>
  <string>MacACGuard</string>
  <key>CFBundleIdentifier</key>
  <string>com.77skala77.macacguard</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Mac AC Guard</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.3.0</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  echo "Applying ad-hoc code signature..."
  codesign --force --deep --sign - "$APP_PATH"
else
  echo "Warning: codesign is unavailable; app bundle was created without a signature." >&2
fi

echo "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"

echo "Created universal app: $APP_PATH"
