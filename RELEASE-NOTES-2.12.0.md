# MechaKeys 2.12.0

## New

- Validated custom sound-pack importing with documented key, Space, Delete, Enter, mouse and release filenames.
- Optional subtle pitch variation and typing-speed dynamics in the existing preloaded polyphonic engine.
- Held-key repeat suppression and optional custom-pack key-release sounds.
- Event-driven automatic pause while a microphone is active, with no continuous microphone polling.

## Performance and safety

- Preserves 25 ms stale-event protection, wake coalescing and 30-second idle audio suspension.
- Custom packs are size, duration, type and symbolic-link checked, copied through staging, and contain no executable content.
- Preserves event-driven notch hover, Bluetooth pause, Input Monitoring, universal Intel/Apple Silicon support and hardened community signing.
