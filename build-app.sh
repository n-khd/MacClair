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

# Sparkle : activé seulement si le framework est disponible. Sans lui, l'application compile et
# fonctionne normalement, mais sans recherche de mises à jour (voir Sources/MacClair/Updater.swift).
SPARKLE_FW="${SPARKLE_FRAMEWORK_DIR:-}"
if [[ -z "$SPARKLE_FW" && -d "$PWD/vendor/Sparkle.framework" ]]; then
    SPARKLE_FW="$PWD/vendor"
fi
SWIFT_SPARKLE=()
if [[ -n "$SPARKLE_FW" && -d "$SPARKLE_FW/Sparkle.framework" ]]; then
    SWIFT_SPARKLE=(-F "$SPARKLE_FW" -framework Sparkle
        -Xlinker -rpath -Xlinker "@executable_path/../Frameworks")
    echo "Sparkle : $SPARKLE_FW/Sparkle.framework"
else
    echo "Sparkle absent : compilation sans mise à jour automatique."
fi

SDKROOT="$SDKROOT" \
CLANG_MODULE_CACHE_PATH="$PWD/.cache/clang" \
xcrun swiftc -sdk "$SDKROOT" \
    -target "${ARCH}-apple-macosx14.0" -parse-as-library -O \
    -swift-version 5 \
    "${SWIFT_SPARKLE[@]}" \
    -module-cache-path .cache/swift \
    -o .build/MacClair Sources/MacClair/*.swift
# The helper is a separate stdio process; it shares the app's scanner implementation.
SDKROOT="$SDKROOT" CLANG_MODULE_CACHE_PATH="$PWD/.cache/clang" \
xcrun swiftc -sdk "$SDKROOT" -target "${ARCH}-apple-macosx14.0" -O -swift-version 5 \
    -module-cache-path .cache/swift -o .build/macclair-mcp \
    Sources/MacClairMCP/main.swift Sources/MacClair/Scanner.swift \
    Sources/MacClair/Insights.swift Sources/MacClair/SafeTrash.swift
APP="$PWD/dist/MacClair.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/MacClair "$APP/Contents/MacOS/MacClair"
cp .build/macclair-mcp "$APP/Contents/MacOS/macclair-mcp"
cp Assets/hero-storage.png "$APP/Contents/Resources/hero-storage.png"
cp Assets/MacClair.icns "$APP/Contents/Resources/MacClair.icns"
if [[ ${#SWIFT_SPARKLE[@]} -gt 0 ]]; then
    mkdir -p "$APP/Contents/Frameworks"
    rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
    ditto "$SPARKLE_FW/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
fi
VERSION="${MACCLAIR_VERSION:-0.5.0}"
BUILD_NUMBER="${MACCLAIR_BUILD:-5}"
UPDATE_KEYS=""
if [[ -n "${SU_FEED_URL:-}" && -n "${SU_PUBLIC_ED_KEY:-}" ]]; then
    UPDATE_KEYS="<key>SUFeedURL</key><string>${SU_FEED_URL}</string>
<key>SUPublicEDKey</key><string>${SU_PUBLIC_ED_KEY}</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUAllowsAutomaticUpdates</key><true/>"
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacClair</string>
<key>CFBundleIdentifier</key><string>local.macclair.app</string>
<key>CFBundleName</key><string>MacClair</string>
<key>CFBundleIconFile</key><string>MacClair.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION}</string>
<key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
${UPDATE_KEYS}
</dict></plist>
PLIST
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP/Contents/MacOS/macclair-mcp"
else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/macclair-mcp"
fi
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP" >/dev/null
    echo "Signature ad hoc (aucune identité Developer ID fournie)."
else
    # Sparkle : les binaires imbriqués livrés dans l'archive amont ne sont pas signés avec notre
    # identité (même des binaires ad hoc), ce que la notarisation refuse. On les re-signe du plus
    # profond au plus haut, avant de sceller l'application.
    FW="$APP/Contents/Frameworks/Sparkle.framework"
    if [[ -d "$FW" ]]; then
        for item in \
            "$FW/Versions/B/XPCServices/Downloader.xpc" \
            "$FW/Versions/B/XPCServices/Installer.xpc" \
            "$FW/Versions/B/Updater.app" \
            "$FW/Versions/B/Autoupdate"; do
            [[ -e "$item" ]] && codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$item"
        done
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FW/Versions/B"
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FW"
        echo "Sparkle re-signé avec l'identité Developer ID."
    fi
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
    codesign --verify --strict --verbose=2 "$APP"
    echo "Signé avec : $SIGN_IDENTITY"
fi
echo "$APP"
