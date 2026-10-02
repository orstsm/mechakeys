# Install NotchHarbor

## Community download

Supports Apple Silicon and Intel Macs running macOS 13 or newer. No Xcode or paid developer account is needed to use a downloaded app.

1. Download `NotchHarbor-VERSION-universal-community.zip` from the project's [GitHub Releases](https://github.com/orstsm/notchharbor/releases). Do not choose the automatic Source code archive.
2. Unzip it. Quit any running NotchHarbor, then move **NotchHarbor.app** to Applications, replacing your previous copy instead of keeping multiple versions.
3. Open NotchHarbor from Applications. Hover over the notch to reach its controls; reopening it from Finder also reveals controls. A menu-bar icon can be enabled in settings.
4. Enable NotchHarbor in **System Settings → Privacy & Security → Input Monitoring**. Quit and reopen it if macOS asks.
5. Enable **Launch at Login** in NotchHarbor settings if desired.

## macOS security warnings

This community build is ad-hoc signed, **not Developer ID-signed or notarized by Apple**. Only install if you trust the project and download source. If macOS blocks opening, review the per-app approval offered in **System Settings → Privacy & Security**. Never disable Gatekeeper or other system-wide protections. Managed Macs may not permit installation.

An update may require Input Monitoring approval again. If the app opens but keyboard sounds do not work, check the permission for the installed copy and restart the app. Bluetooth audio connections intentionally pause sounds.

## Updates

**Upgrading from MechaKeys:** quit MechaKeys before opening NotchHarbor. After verifying the new app, move the old `MechaKeys.app` from the same Applications folder to Trash so only one installed app remains. Keep `~/Library/Application Support/MechaKeys/` and its sound packs. The source installer handles the app rename with a recoverable backup automatically. Older versions cannot follow the renamed repository's update redirect; download 2.15.0 or newer manually once. A privacy-permission entry may retain the old name until macOS refreshes it.

Use **NotchHarbor Settings → Check for Updates**. Optional daily checks are off by default. When a newer public release is available, open its release page, download the app ZIP and repeat the installation steps. NotchHarbor does not automatically replace itself. Versions before 2.11.0 need a manual download to gain update checking.

## Build from source

With Xcode Command Line Tools installed, run `zsh Tests/run.sh` and `zsh build.sh --build-only` from the repository root. Quit NotchHarbor, then run `zsh install.sh` to install into your user Applications folder with a recoverable previous-version backup. Building alone never replaces the installed app.

For maintainers, publishing instructions are in `docs/UPDATES.md` in the source repository. The optional `release.sh` requires your own Developer ID and notarization credentials; those are not used for community downloads.
