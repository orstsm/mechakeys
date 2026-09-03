#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$PROJECT_DIR/MechaKeys.app"
UPLOAD_ZIP="$DIST_DIR/MechaKeys-notarization.zip"
FINAL_ZIP="$DIST_DIR/MechaKeys-2.7.0.zip"

: "${MECHAKEYS_SIGNING_IDENTITY:?Set this to your Developer ID Application identity}"
: "${MECHAKEYS_NOTARY_PROFILE:?Set this to your notarytool keychain profile}"

MECHAKEYS_SIGNING_IDENTITY="$MECHAKEYS_SIGNING_IDENTITY" "$PROJECT_DIR/build.sh"

mkdir -p "$DIST_DIR"
rm -f "$UPLOAD_ZIP" "$FINAL_ZIP"
ditto -c -k --keepParent "$APP_DIR" "$UPLOAD_ZIP"

xcrun notarytool submit "$UPLOAD_ZIP" \
    --keychain-profile "$MECHAKEYS_NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$FINAL_ZIP"
rm -f "$UPLOAD_ZIP"

echo "Created notarized release: $FINAL_ZIP"
