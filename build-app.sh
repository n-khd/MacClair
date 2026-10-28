#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build .cache/clang .cache/swift
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
if [[ "$ARCH" != arm64 && "$ARCH" != x86_64 ]]; then
    echo "Architecture macOS non prise en charge : $ARCH" >&2
    exit 1
fi
SDKROOT="$SDKROOT" \
CLANG_MODULE_CACHE_PATH="$PWD/.cache/clang" \
xcrun swiftc -sdk "$SDKROOT" \
    -target "${ARCH}-apple-macosx14.0" -parse-as-library -O \
    -module-cache-path .cache/swift \
    -o .build/MacClair Sources/MacClair/*.swift
APP="$PWD/dist/MacClair.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/MacClair "$APP/Contents/MacOS/MacClair"
cp Assets/hero-storage.png "$APP/Contents/Resources/hero-storage.png"
cp Assets/MacClair.icns "$APP/Contents/Resources/MacClair.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacClair</string>
<key>CFBundleIdentifier</key><string>local.macclair.app</string>
<key>CFBundleName</key><string>MacClair</string>
<key>CFBundleIconFile</key><string>MacClair.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.5.0</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null
echo "$APP"
