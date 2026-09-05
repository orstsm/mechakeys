# Install MechaKeys

## Community download

Supports Apple Silicon and Intel Macs running macOS 13 or newer. No Xcode or paid developer account is needed to use a downloaded app.

1. Download `MechaKeys-VERSION-universal-community.zip` from the project's [GitHub Releases](https://github.com/orstsm/mechakeys/releases). Do not choose the automatic Source code archive.
2. Unzip it. Quit any running MechaKeys, then move **MechaKeys.app** to Applications, replacing your previous copy instead of keeping multiple versions.
3. Open MechaKeys from Applications. Hover over the notch to reach its controls; reopening it from Finder also reveals controls. A menu-bar icon can be enabled in settings.
4. Enable MechaKeys in **System Settings → Privacy & Security → Input Monitoring**. Quit and reopen it if macOS asks.
5. Enable **Launch at Login** in MechaKeys settings if desired.

## macOS security warnings

This community build is ad-hoc signed, **not Developer ID-signed or notarized by Apple**. Only install if you trust the project and download source. If macOS blocks opening, review the per-app approval offered in **System Settings → Privacy & Security**. Never disable Gatekeeper or other system-wide protections. Managed Macs may not permit installation.

An update may require Input Monitoring approval again. If the app opens but keyboard sounds do not work, check the permission for the installed copy and restart the app. Bluetooth audio connections intentionally pause sounds.

## Updates

Use **MechaKeys Settings → Check for Updates**. Optional daily checks are off by default. When a newer public release is available, open its release page, download the app ZIP and repeat the installation steps. MechaKeys does not automatically replace itself. Versions before 2.11.0 need a manual download to gain update checking.

## Build from source

With Xcode Command Line Tools installed, run `zsh Tests/run.sh` and `zsh build.sh --build-only` from the repository root. Quit MechaKeys, then run `zsh install.sh` to install into your user Applications folder with a recoverable previous-version backup. Building alone never replaces the installed app.

For maintainers, publishing instructions are in `docs/UPDATES.md` in the source repository. The optional `release.sh` requires your own Developer ID and notarization credentials; those are not used for community downloads.
