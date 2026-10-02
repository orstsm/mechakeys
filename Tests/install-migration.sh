#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
APP="$PROJECT_DIR/.build/Products/NotchHarbor.app"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/notchharbor-migration.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
xcrun swiftc -module-cache-path "$PROJECT_DIR/.build/install-cache" "$PROJECT_DIR/Tests/InstallApp.swift" -o "$TEST_ROOT/install"
mkdir "$TEST_ROOT/Applications"
ditto "$APP" "$TEST_ROOT/Applications/MechaKeys.app"
"$TEST_ROOT/install" "$APP" "$TEST_ROOT/Applications/NotchHarbor.app"
[[ ! -e "$TEST_ROOT/Applications/MechaKeys.app" ]]
[[ -d "$TEST_ROOT/Applications/NotchHarbor.app" ]]
BACKUPS=("$TEST_ROOT/Applications"/.notchharbor-install-*.noindex/MechaKeys.bundle-backup(N))
[[ ${#BACKUPS[@]} -eq 1 ]]
codesign --verify --deep --strict "$BACKUPS[1]"
"$TEST_ROOT/install" "$APP" "$TEST_ROOT/Applications/NotchHarbor.app"
PREVIOUS=("$TEST_ROOT/Applications"/.notchharbor-install-*.noindex/previous.bundle-backup(N))
[[ ${#PREVIOUS[@]} -eq 1 ]]
codesign --verify --deep --strict "$PREVIOUS[1]"
if "$TEST_ROOT/install" "$APP" "$APP"; then
    echo "Installer accepted source as destination" >&2
    exit 1
fi
mkdir "$TEST_ROOT/unrelated"
ditto "$APP" "$TEST_ROOT/unrelated/MechaKeys.app"
plutil -replace CFBundleIdentifier -string invalid.unrelated.app "$TEST_ROOT/unrelated/MechaKeys.app/Contents/Info.plist"
if "$TEST_ROOT/install" "$APP" "$TEST_ROOT/unrelated/NotchHarbor.app"; then
    echo "Installer migrated an unrelated app" >&2
    exit 1
fi
[[ -d "$TEST_ROOT/unrelated/MechaKeys.app" && ! -e "$TEST_ROOT/unrelated/NotchHarbor.app" ]]
echo "PASS: legacy migration, upgrade backup, source protection, unrelated-app refusal"
