# MechaKeys

A lightweight native macOS notch app that plays low-latency mechanical sounds for global key presses and mouse clicks, with optional menu-bar controls.

MechaKeys includes three sound profiles inspired by modern mechanical keyboards:

- **Default** — four natural variations extracted from the app owner's recorded keycap click
- **K Pro Red** — ten natural regular-key variations, four distinct Space variations, and the original mouse-click recording supplied by the app owner
- **Alpaca** — recorded mouse, regular-key, Delete/Backspace, and Space variations supplied by the app owner

MechaKeys lives natively in your MacBook notch. Hover over the physical notch anytime to expand the control center, adjust volume, switch sound profiles, play a test sound, or mute playback. Your choices are remembered between launches. If desired, you can also toggle an optional menu-bar icon from the settings.

When a Bluetooth headset, earphone, or speaker connects, MechaKeys pauses automatically. It resumes after the last connected Bluetooth audio output disconnects, provided sounds were manually enabled beforehand. Bluetooth keyboards, mice, and other non-audio accessories are ignored. Audio-route changes are debounced and rebuild the audio engine so connecting or disconnecting devices cannot leave playback stuck.

Enable **Launch at Login** in the MechaKeys panel to start it automatically after restarting your Mac. Turn sounds off from the panel instead of quitting the app when you want silence.

## Energy behavior

MechaKeys keeps its audio engine warm for 30 seconds after input, then stops it completely. During a cold wake, keyboard events are coalesced so only the newest key can sound after audio becomes ready; mouse clicks during the wake are discarded. Warm input events older than 25 milliseconds are dropped instead of being played late. Turning sounds off removes the global input monitor and stops the audio engine immediately. Permission polling also stops as soon as access is granted.

## Releases

To publish a community app download from **GitHub Desktop**, commit/push the update, then create and push its version tag from History (for example `v2.11.1`). The included GitHub Actions workflow tests, builds and publishes the universal ZIP. Ordinary commits do not publish releases. Follow [UPDATES.md](UPDATES.md) for the complete checklist and failure recovery.

Version 2.11.0 adds **Settings → Check for Updates** and opt-in daily checks. Checks read public GitHub release metadata; playback still works offline. Downloads and installation remain manual. See [UPDATES.md](UPDATES.md) for publishing instructions and [BATTERY-TEST.md](BATTERY-TEST.md) for the verified idle result and battery measurement procedure.

Community builds are hardened but ad-hoc signed and **not notarized by Apple**. They may be shared with that warning, but macOS may block first launch or require explicit approval. Do not ask users to disable system security. A Developer ID-signed, notarized release requires a **Developer ID Application** certificate and an Apple notarization profile:

```sh
export MECHAKEYS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export MECHAKEYS_NOTARY_PROFILE="mechakeys-notary"
./release.sh
```

The release script signs with hardened runtime and a secure timestamp, submits the app to Apple's notary service, staples and validates the ticket, verifies Gatekeeper acceptance, and produces the final ZIP in `dist/`.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools

The default build is universal and supports both Apple Silicon and Intel Macs.

## Build and run

```sh
zsh Tests/run.sh
zsh build.sh --build-only
# Quit any running MechaKeys before installing.
zsh install.sh
open "$HOME/Applications/MechaKeys.app"
```

To create a personal drag-to-Applications DMG and a GitHub-ready source archive:

```sh
./package-local.sh
```

On first launch, allow MechaKeys in **System Settings → Privacy & Security → Input Monitoring**. If it was already open when access was granted, quit and reopen it once. MechaKeys uses a passive event listener: it observes numeric key codes and mouse-button-down types only, and never changes or stores what you type.

The Default and K Pro Red recordings are intended for the app owner's personal use. Confirm that you have redistribution rights before publishing those audio assets in a public repository or release.

## Reliability update (2.10.1)

Hover is driven by mouse movement with no recurring pointer timer or intentional opening delay. A single cancellable exit deadline handles closing. The audio engine still sleeps after 30 seconds of inactivity; notch detection and audio sleep are separate.

Run `zsh Tests/run.sh` for regression checks and `zsh build.sh --build-only` to build. Builds no longer install automatically. Quit MechaKeys, then run `zsh install.sh` to install a verified build in your Applications folder while preserving the previous version. Local signatures can still require Input Monitoring reauthorization after replacement. Community releases disclose their lack of notarization; Developer ID signing and notarization are available via `release.sh` when you have the required credentials.

See [RELIABILITY.md](RELIABILITY.md) for the design, test coverage, and remaining acceptance checks. Build products are ignored by Git; attach packaged installers to GitHub Releases rather than committing them as source.
