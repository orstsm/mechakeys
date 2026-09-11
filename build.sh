#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/Products/MechaKeys.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
ARCHS=(arm64 x86_64)

# Prefer the stable SDK when a newer Command Line Tools compiler is installed
# alongside a prerelease SDK with a different Swift patch version.
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
elif [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/PrivacyInfo.xcprivacy" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
cp "$PROJECT_DIR/Resources/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$RESOURCES_DIR/Sounds"
cp -R "$PROJECT_DIR/Resources/Sounds" "$RESOURCES_DIR/Sounds"
rm -rf "$RESOURCES_DIR/Licenses"
rm -f "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"

for arch in "${ARCHS[@]}"; do
    ARCH_BUILD_DIR="$BUILD_DIR/$arch"
    ARCH_MODULE_CACHE_DIR="$MODULE_CACHE_DIR/$arch"
    mkdir -p "$ARCH_BUILD_DIR" "$ARCH_MODULE_CACHE_DIR"

    xcrun swiftc \
        -parse-as-library \
        -O \
        -sdk "$SDK_PATH" \
        -module-cache-path "$ARCH_MODULE_CACHE_DIR" \
        -target "$arch-apple-macos13.0" \
        -framework AppKit \
        -framework ApplicationServices \
        -framework AVFoundation \
        -framework Combine \
        -framework CoreAudio \
        -framework CoreGraphics \
        -framework QuartzCore \
        -framework ServiceManagement \
        -framework SwiftUI \
        "$PROJECT_DIR"/Sources/*.swift \
        -o "$ARCH_BUILD_DIR/MechaKeys"
done

xcrun lipo -create \
    "$BUILD_DIR/arm64/MechaKeys" \
    "$BUILD_DIR/x86_64/MechaKeys" \
    -output "$MACOS_DIR/MechaKeys"

SIGNING_IDENTITY="${MECHAKEYS_SIGNING_IDENTITY:--}"

# Files copied from development tools can carry provenance metadata that makes
# Launch Services reject an otherwise valid local bundle. Strip it before the
# final signature so Finder and Spotlight can open and index the app normally.
xattr -cr "$APP_DIR"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "Warning: ad-hoc community build, NOT notarized by Apple. Disclose this when sharing."
    codesign \
        --force \
        --deep \
        --options runtime \
        --sign - \
        "$APP_DIR"
else
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$APP_DIR"
fi

plutil -lint "$CONTENTS_DIR/Info.plist" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
xcrun lipo -info "$MACOS_DIR/MechaKeys"

echo "Built $APP_DIR"
echo "Builds never replace the installed app. Quit MechaKeys, then run: zsh install.sh"
