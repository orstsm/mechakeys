#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/.build"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$BUILD_DIR/Products/MechaKeys.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$PROJECT_DIR/Info.plist")"
DMG_PATH="$DIST_DIR/MechaKeys-$VERSION-universal-local.dmg"
APP_ZIP="$DIST_DIR/MechaKeys-$VERSION-universal-personal.zip"
SOURCE_ZIP="$DIST_DIR/MechaKeys-$VERSION-github-source.zip"

"$PROJECT_DIR/build.sh" --build-only

mkdir -p "$DIST_DIR"
DMG_STAGE="$(mktemp -d "$BUILD_DIR/dmg-stage.XXXXXX")"
SOURCE_STAGE="$(mktemp -d "$BUILD_DIR/source-stage.XXXXXX")"
trap 'rm -rf -- "$DMG_STAGE" "$SOURCE_STAGE"' EXIT

ditto "$APP_DIR" "$DMG_STAGE/MechaKeys.app"
ln -s /Applications "$DMG_STAGE/Applications"
cp "$PROJECT_DIR/INSTALL.md" "$DMG_STAGE/Read Me First.md"

ditto -c -k --keepParent --norsrc --noextattr "$APP_DIR" "$APP_ZIP"

if hdiutil create \
    -volname "MechaKeys $VERSION" \
    -srcfolder "$DMG_STAGE" \
    -format UDZO \
    -ov \
    "$DMG_PATH"; then
    echo "Created personal DMG installer: $DMG_PATH"
else
    echo "DMG creation is unavailable in this environment; use the universal app ZIP."
fi

SOURCE_ROOT="$SOURCE_STAGE/MechaKeys"
mkdir -p "$SOURCE_ROOT"
cp "$PROJECT_DIR/MechaKeysApp.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/AppDelegate.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/UpdateChecker.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/UpdateSettingsView.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/ShelfModel.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/NotchWindowController.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/NotchView.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/GlobalKeyboardMonitor.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/KeyboardAudioEngine.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/InputAudioController.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/BluetoothAudioMonitor.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/LaunchAtLoginManager.swift" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/Info.plist" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/PrivacyInfo.xcprivacy" "$SOURCE_ROOT/"
cp -R "$PROJECT_DIR/Resources" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/build.sh" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/install.sh" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/.gitignore" "$SOURCE_ROOT/"
cp -R "$PROJECT_DIR/Tests" "$SOURCE_ROOT/"
cp -R "$PROJECT_DIR/.github" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/release.sh" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/package-local.sh" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/README.md" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/INSTALL.md" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/SECURITY.md" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/RELIABILITY.md" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/UPDATES.md" "$SOURCE_ROOT/"
cp "$PROJECT_DIR/BATTERY-TEST.md" "$SOURCE_ROOT/"

ditto -c -k --keepParent --norsrc --noextattr "$SOURCE_ROOT" "$SOURCE_ZIP"

echo "Created universal app archive: $APP_ZIP"
echo "Created GitHub source archive: $SOURCE_ZIP"
