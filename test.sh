#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build .cache/clang .cache/swift
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
export CLANG_MODULE_CACHE_PATH="$PWD/.cache/clang"
for suite in Scanner Insights Audits ImageAudits SafeTrash; do
    case "$suite" in
        Scanner) source=Scanner.swift ;;
        Insights) source=Insights.swift ;;
        Audits) source=Audits.swift ;;
        ImageAudits) source=ImageAudits.swift ;;
        SafeTrash) source=SafeTrash.swift ;;
    esac
    extra=()
    if [[ "$suite" == "Scanner" ]]; then extra=(Sources/MacClair/SafeTrash.swift); fi
    xcrun swiftc -sdk "$SDKROOT" -target "${ARCH}-apple-macosx14.0" \
        -module-cache-path .cache/swift -o ".build/${suite}Smoke" \
        "Sources/MacClair/$source" "${extra[@]}" "Tests/${suite}Smoke.swift"
    ".build/${suite}Smoke"
done
