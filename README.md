# MechaKeys

Mechanical keyboard and mouse sounds for macOS, controlled from your MacBook's notch.

Hover over the notch to turn sounds on or off, choose a profile, change volume, or open settings. MechaKeys is a standalone app: **NotchShelf and boringNotch are not required**. An optional menu-bar icon provides another way to reach the controls.

## Download and install

Open [GitHub Releases](https://github.com/orstsm/mechakeys/releases) and download the versioned **universal-community.zip** app asset. Unzip it and move **MechaKeys.app** to Applications. GitHub's automatic “Source code” ZIP is for developers, not an installer. If no release is listed, a downloadable build has not been published yet.

- **Requirements:** macOS 13 or newer; Apple Silicon or Intel Mac. The notch interface is designed for MacBooks with a physical notch.
- **Permission:** enable MechaKeys in System Settings → Privacy & Security → Input Monitoring for keyboard and mouse sounds.
- **Community build:** ad-hoc signed and **not notarized by Apple**. macOS may block opening or require explicit per-app approval. Only install if you trust the project; never disable Gatekeeper or other system-wide protections. Updates may require Input Monitoring approval again.

See [installation and troubleshooting](INSTALL.md). Downloaded builds do not require Xcode or developer tools.

## Features

- **Notch controls:** event-driven hover, sound toggle, profile selection, volume, test playback, About, settings and Quit.
- **Recorded and custom profiles:** Default, K Pro Red, Alpaca, Holy Panda, MX Blue, MX Brown, NK Cream and Typewriter, plus validated user-imported sound packs stored in Application Support.
- **Special sounds:** K Pro Red includes regular-key, Space and mouse samples; Alpaca additionally includes Delete/Backspace samples. Default shares four recorded variations across inputs.
- **Spatial panning:** left and right keyboard regions subtly pan toward the corresponding speaker.
- **Bluetooth audio pause:** pauses for connected Bluetooth audio devices and resumes when they disconnect, provided sounds were manually enabled. Bluetooth mice and keyboards do not trigger this pause.
- **Natural dynamics:** optional subtle pitch variation, typing-speed response, held-key repeat suppression and custom-pack release sounds.
- **Call-aware pause:** optionally pauses while a microphone is active using Core Audio property events—no repeating microphone poll.
- **Low-latency playback:** all active sounds are preloaded into the existing polyphonic engine with stale-event dropping. Audio stops after 30 seconds without input; cold wake retains only the newest key and discards delayed mouse clicks.
- **Convenience:** launch at login, remembered preferences and optional menu-bar access.
- **Update checks:** Settings → Check for Updates, plus optional daily checks (off by default). Downloads and installation remain manual.

## Privacy and energy use

Playback works offline. MechaKeys observes physical key/button events to play sounds; it does not record typed text, collect analytics, or upload input data. Optional update checks contact GitHub for public release information. See [security and privacy](SECURITY.md).

Hover has no repeating pointer-polling timer, and audio suspends after 30 seconds of inactivity. An idle test confirmed release of the audio sleep assertion, but **no app-specific battery-drain percentage has been established**. See [battery measurements and test procedure](docs/BATTERY-TEST.md).

## Build from source

Install Xcode Command Line Tools, then run these commands from the repository folder:

```sh
zsh Tests/run.sh
zsh build.sh --build-only
# Quit MechaKeys before installing the new build.
zsh install.sh
```

Building does not replace your installed app. The explicit installer uses your user Applications folder and preserves the previous version for recovery.

## Publish an update from GitHub Desktop

Update the version and release notes, commit/push the changes, then create and push the matching version tag from **History** (for example `v2.12.0`). GitHub Actions tests, builds and publishes the universal community ZIP, installation instructions and checksums. Ordinary commits do not publish releases.

Follow the [release checklist](docs/UPDATES.md), including how to check build failures. No paid Apple Developer account is needed for community releases. The optional `release.sh` supports notarized releases when you have the required Apple credentials.

## Repository guide

| Location | Purpose |
| --- | --- |
| `Sources/` | Current app code: notch UI, audio, Bluetooth, permissions, updates |
| `Resources/` | App icons and 83 active sound recordings |
| `Tests/` | Regression tests and installation verification utility |
| `docs/` | Release instructions, reliability notes and battery evidence |
| `.github/workflows/` | Automated tests and tag-triggered community releases |
| Root scripts and plists | Build, package, install, identity and privacy configuration |

`.build/` and `dist/` are local generated output, ignored by Git—not files users need to commit. Release downloads belong in GitHub Releases, not in the source tree.

The Holy Panda, MX Blue, MX Brown, NK Cream and Typewriter recordings are included by private permission from their rights holder. All audio rights are reserved: the recordings may be used only as part of MechaKeys and may not be extracted, copied, repackaged, reused or redistributed separately.

Custom pack creators should follow the validated format in [docs/CUSTOM-SOUND-PACKS.md](docs/CUSTOM-SOUND-PACKS.md). Imported packs are limited to short local WAV, AIFF, CAF, or MP3 files; scripts and executable content are never copied.

Built by **orstsm**.
