#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mechakeys-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_DIR"' EXIT
cd "$PROJECT_DIR"
xcrun swiftc -module-cache-path "$TEST_DIR/cache" Sources/ShelfModel.swift Tests/HoverStateTests.swift -o "$TEST_DIR/hover"
"$TEST_DIR/hover"
xcrun swiftc -module-cache-path "$TEST_DIR/cache" Sources/GlobalKeyboardMonitor.swift Sources/KeyboardAudioEngine.swift Sources/InputAudioController.swift Tests/AudioLifecycleTests.swift -o "$TEST_DIR/audio"
"$TEST_DIR/audio"
xcrun swiftc -module-cache-path "$TEST_DIR/cache" Sources/UpdateChecker.swift Tests/UpdateTests.swift -o "$TEST_DIR/updates"
"$TEST_DIR/updates"
xcrun swiftc -typecheck -module-cache-path "$TEST_DIR/cache" Tests/InstallApp.swift
zsh -n build.sh install.sh package-local.sh package-community.sh release.sh
VERSION="$(plutil -extract CFBundleShortVersionString raw Info.plist)"
zsh package-community.sh "v$VERSION" --validate-only
for INVALID_TAG in v0.0.0 v2.11.1-beta invalid; do
    if zsh package-community.sh "$INVALID_TAG" --validate-only; then
        echo "Invalid release tag was accepted: $INVALID_TAG" >&2
        exit 1
    fi
done
plutil -lint Info.plist PrivacyInfo.xcprivacy
