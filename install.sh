#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
xcrun swift -module-cache-path "$PROJECT_DIR/.build/install-cache" "$PROJECT_DIR/Tests/InstallApp.swift" "$PROJECT_DIR/.build/Products/NotchHarbor.app" "$HOME/Applications/NotchHarbor.app"
