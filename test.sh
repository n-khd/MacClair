#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build .cache/clang .cache/swift
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
export CLANG_MODULE_CACHE_PATH="$PWD/.cache/clang"
for suite in Scanner Insights Audits ImageAudits SafeTrash PrivacyAudits DeveloperAudits Uninstaller Activity; do
    case "$suite" in
        Scanner) source=Scanner.swift ;;
        Insights) source=Insights.swift ;;
        Audits) source=Audits.swift ;;
        ImageAudits) source=ImageAudits.swift ;;
        SafeTrash) source=SafeTrash.swift ;;
        PrivacyAudits) source=PrivacyAudits.swift ;;
        DeveloperAudits) source=DeveloperAudits.swift ;;
        Uninstaller) source=Uninstaller.swift ;;
        Activity) source=Activity.swift ;;
    esac
    extra=()
    if [[ "$suite" == "Scanner" ]]; then extra=(Sources/MacClair/SafeTrash.swift); fi
    xcrun swiftc -sdk "$SDKROOT" -target "${ARCH}-apple-macosx14.0" \
        -module-cache-path .cache/swift -o ".build/${suite}Smoke" \
        "Sources/MacClair/$source" "${extra[@]}" "Tests/${suite}Smoke.swift"
    ".build/${suite}Smoke"
done

# Compile the real MCP helper and exercise its stdio protocol.
xcrun swiftc -sdk "$SDKROOT" -target "${ARCH}-apple-macosx14.0" \
    -swift-version 5 -module-cache-path .cache/swift -o .build/macclair-mcp-test \
    Sources/MacClairMCP/main.swift Sources/MacClair/Scanner.swift \
    Sources/MacClair/Insights.swift Sources/MacClair/SafeTrash.swift
python3 Tests/MCPSmoke.py .build/macclair-mcp-test
