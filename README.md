# MechaKeys

A lightweight macOS menu-bar app that plays low-latency mechanical sounds for global key presses and mouse clicks.

MechaKeys includes three sound profiles inspired by modern mechanical keyboards:

- **Default** — four natural variations extracted from the app owner's recorded keycap click
- **K Pro Red** — ten natural regular-key variations, four distinct Space variations, and the original mouse-click recording supplied by the app owner
- **Alpaca** — recorded mouse, regular-key, Delete/Backspace, and Space variations supplied by the app owner

The menu-bar controls let you turn sounds on or off, select a profile, change the volume, and play a test sound. Your choices are remembered between launches. The About page documents the complete feature set and privacy behavior inside the app.

When a Bluetooth headset, earphone, or speaker connects, MechaKeys pauses automatically. It resumes after the last connected Bluetooth audio output disconnects, provided sounds were manually enabled beforehand. Bluetooth keyboards, mice, and other non-audio accessories are ignored. Audio-route changes are debounced and rebuild the audio engine so connecting or disconnecting devices cannot leave playback stuck.

Enable **Launch at Login** in the MechaKeys panel to keep its keyboard icon available automatically after restarting your Mac. Turn sounds off from the panel instead of quitting the app when you want silence.

## Energy behavior

MechaKeys keeps its audio engine warm for 30 seconds after input, then stops it completely. During a cold wake, keyboard events are coalesced so only the newest key can sound after audio becomes ready; mouse clicks during the wake are discarded. Warm input events older than 25 milliseconds are dropped instead of being played late. Turning sounds off removes the global input monitor and stops the audio engine immediately. Permission polling also stops as soon as access is granted.

## Production releases

Local builds are hardened but ad-hoc signed and must not be distributed. A public release requires a **Developer ID Application** certificate and an Apple notarization profile:

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
chmod +x build.sh
./build.sh
open MechaKeys.app
```

To create a personal drag-to-Applications DMG and a GitHub-ready source archive:

```sh
./package-local.sh
```

On first launch, allow MechaKeys in **System Settings → Privacy & Security → Input Monitoring**. If it was already open when access was granted, quit and reopen it once. MechaKeys uses a passive event listener: it observes numeric key codes and mouse-button-down types only, and never changes or stores what you type.

The Default and K Pro Red recordings are intended for the app owner's personal use. Confirm that you have redistribution rights before publishing those audio assets in a public repository or release.
