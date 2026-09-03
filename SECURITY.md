# MechaKeys security model

## Input access

MechaKeys requests macOS Input Monitoring permission because its core function requires observing global key-down and mouse-button-down events. The event tap is passive (`listenOnly`): it cannot change, suppress, or inject input. For keyboard events, only the numeric physical key code is read. For mouse events, only the button number is read; pointer coordinates are not accessed. These values are used immediately to choose and position a sound, then discarded.

Input monitoring is removed completely whenever sounds are turned off. MechaKeys does not reconstruct text, inspect clipboard contents, write input events to disk, or transmit data.

## Data and network

The app contains no networking client and collects no analytics. It stores only these local preferences in `UserDefaults`:

- sounds enabled
- volume
- selected switch profile
- whether the Input Monitoring prompt has been shown

The included privacy manifest declares no tracking or collected data.

MechaKeys reads CoreAudio's local device list to determine whether an available output uses Bluetooth transport. It does not access Bluetooth pairing data, device addresses, microphone input, or audio content. Device identifiers are used only in memory and are never stored or transmitted.

## Runtime security

Release builds must use a Developer ID Application certificate, hardened runtime, a secure timestamp, and Apple notarization. The release script refuses to run without a signing identity and notary keychain profile. No hardened-runtime exceptions are requested.

Local builds are ad-hoc signed and are for development on one Mac only. They must not be distributed.

## Launch at login

When installed in `/Applications`, MechaKeys uses Apple's `SMAppService.mainApp`. Local development copies use a user-owned LaunchAgent with mode `0600`; it runs only the current app executable and has no elevated privileges.
