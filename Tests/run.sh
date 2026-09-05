#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mechakeys-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_DIR"' EXIT
cd "$PROJECT_DIR"
xcrun swiftc -module-cache-path "$TEST_DIR/cache" ShelfModel.swift Tests/HoverStateTests.swift -o "$TEST_DIR/hover"
"$TEST_DIR/hover"
xcrun swiftc -module-cache-path "$TEST_DIR/cache" GlobalKeyboardMonitor.swift KeyboardAudioEngine.swift InputAudioController.swift Tests/AudioLifecycleTests.swift -o "$TEST_DIR/audio"
"$TEST_DIR/audio"
xcrun swiftc -typecheck -module-cache-path "$TEST_DIR/cache" Tests/InstallApp.swift
zsh -n build.sh install.sh package-local.sh release.sh
plutil -lint Info.plist PrivacyInfo.xcprivacy
