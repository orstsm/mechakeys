# MechaKeys security model

## Input access

MechaKeys requests macOS Input Monitoring permission to observe global key-down, key-up and mouse-button-down events. The audio event tap is passive (`listenOnly`) and reads physical key codes and button numbers, not typed text. Key-up state suppresses held-key repeats and can trigger an optional custom-pack release sound. Separately, the notch observes mouse movement and reads the current pointer position locally to open its controls. Pointer positions are not recorded or transmitted. There is no recurring hover polling timer; movement opens the notch and a single exit deadline closes it.

The audio input tap is removed when sounds are off. Mouse movement observation remains available for the notch. MechaKeys does not reconstruct text, inspect clipboard contents, write input events to disk, or transmit data.

## Data and network

Sound playback works offline and collects no analytics. Manual update checks, or optional daily checks (off by default), request public release metadata from `api.github.com/repos/orstsm/mechakeys/releases/latest`. GitHub receives the connecting IP address and a generic app User-Agent, but no typed text, key codes, pointer positions, sound settings, account tokens, or persistent app-generated identifier. Checks use an ephemeral session without cookies or disk caching, with timeouts, a 1 MiB response limit, and no redirects. Release links must use HTTPS and the expected repository on github.com. Opening a release uses the user's browser and its normal privacy settings. Nothing is automatically downloaded or installed.

Local preferences in `UserDefaults` include:

- sounds enabled
- volume
- selected switch profile
- whether the Input Monitoring prompt has been shown
- optional menu-bar icon and notch visibility/recovery preferences
- pitch variation, typing dynamics, repeat suppression, release-sound and microphone-pause choices
- the identifier of a selected custom sound pack
- daily-update opt-in and last update-attempt time

The included privacy manifest declares no tracking or collected data.

MechaKeys reads CoreAudio's local device list to determine whether an available output uses Bluetooth transport. When automatic microphone pause is enabled, it also subscribes to Core Audio device-run-state changes and pauses while any microphone is active. This is event-driven and does not continuously poll. MechaKeys never opens the microphone or reads, records, stores, or transmits microphone audio. Device identifiers are used only in memory and are never stored or transmitted.

Custom sound packs are stored under the user's Application Support folder. Imports accept only short audio files and recognized metadata, reject symbolic links and enforce file-count, size and duration limits. Files are copied through a staging folder and validated again before activation. Imported audio remains local and is never uploaded.

The included Holy Panda, MX Blue, MX Brown, NK Cream and Typewriter recordings are immutable application resources loaded from the signed bundle. They are included by private permission from their rights holder and are not licensed for extraction, reuse, repackaging or separate redistribution.

## Runtime security

The optional notarized release path uses a Developer ID Application certificate, hardened runtime, a secure timestamp, and Apple notarization. `release.sh` refuses to run without a signing identity and notary keychain profile. The community workflow instead uses ad-hoc signing with hardened runtime. No hardened-runtime exceptions are requested.

Community builds are ad-hoc signed and are not notarized by Apple. Shared community releases must prominently disclose that limitation. macOS may block opening them or require explicit per-app approval; users must not disable Gatekeeper or other system-wide security protections.

## Launch at login

When installed in `/Applications` or the user's `Applications` folder, MechaKeys uses Apple's `SMAppService.mainApp`. Legacy LaunchAgents are retained until migration is approved, then removed. Development copies elsewhere use a user-owned LaunchAgent with mode `0600`, launching the app through `/usr/bin/open` without a shell or elevated privileges.

Building and packaging never replace an installed application. The separate installer verifies a staged bundle, refuses to replace a running app, and uses a same-volume atomic exchange with a preserved rollback copy. Shared ad-hoc builds must disclose their community status without implying Apple notarization or verified developer identity.
