# Reliability design and verification

## Hover

macOS mouse movement -> local/global event observer -> notch bounds check -> committed window geometry.

There is no repeating pointer timer and no opening dwell. One 290 ms timer is scheduled after leaving an expanded shelf; it rechecks the actual pointer before closing, and is canceled on return. The collapsed window remains click-through. Movement observation stops while hidden or the display sleeps and resumes when needed. This avoids 30 checks per second when the pointer is stationary. It does not mean zero processing while the mouse moves elsewhere, or hard real-time delivery under system load. Audio retains its independent 30-second idle sleep.

AppKit event observers are asynchronous: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html

## Recovery and state

- Window dimensions have one definition shared by the view and window controller.
- Audio work carries a generation token so queued pre-suspend input cannot revive stale playback after a route rebuild.
- Audio failure reaches observable UI state; the next test/input can retry engine startup.
- Failed input-tap creation retains retry checks even when permission preflight passes.
- Bluetooth lifecycle and evaluation state are confined to one queue, with shutdown guards.
- Non-finite/out-of-range saved volume values are normalized at the model boundary.
- An unapproved login item is no longer displayed as enabled; migration preserves legacy registration until modern registration succeeds. Disabling removes legacy registration too.
- Visibility resets to visible on launch intentionally, preserving Finder recovery when no menu icon is enabled.

## Installation and releases

Builds and packaging have no installation side effects. The explicit installer verifies a staged bundle, refuses replacement while MechaKeys is running, and atomically exchanges bundles on the same volume. The previous app is retained inside a hidden `.noindex` directory with a non-app backup suffix. Local builds are still ad-hoc signed. Community releases disclose their lack of notarization. Optional notarized builds require the developer's own signing and notarization credentials.

## Historical verification — 2.10.1

- Hover-model tests: immediate first entry, canceled close, 100 repeated cycles, manual reopening, explicit-close rearming, visibility.
- Audio tests with a controlled engine: latest-key wake coalescing, wake mouse discard, idle suspension, cancellation during wake, failure notification.
- Installer typecheck, shell syntax, plist lint, whitespace checks.
- Optimized universal Intel/Apple Silicon build and strict bundle signature verification.
- Atomic installer exercised on this Mac; previous working version retained.
- Installed app launched and on/off changed state; UI confirms version 2.10.1.

## Still requires live acceptance

Input Monitoring may be invalidated by a signature replacement. The user may need to reauthorize the installed app. Do not change that security setting automatically.

Ordinary hardware-notch hover, long idle/re-entry, Bluetooth route transitions, login approval/migration across logout, full-screen/multiple displays, and battery A/B testing remain manual acceptance tests. Model tests cannot prove real pointer delivery or speaker latency. No new battery savings percentage is claimed.

User acceptance update: Bluetooth pause/resume was confirmed working after installation. An unplugged idle check confirmed release of the audio sleep assertion; see [battery testing](BATTERY-TEST.md). Long-duration battery A/B testing remains outstanding.

CI runs regression tests and universal builds. The separate version-tag workflow publishes community downloads; see [publishing updates](UPDATES.md). Check the actual GitHub Actions run for hosted results rather than treating local verification as proof that a release was published.
