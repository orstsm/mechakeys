# Custom sound packs

MechaKeys imports a folder of short audio recordings into:

`~/Library/Application Support/MechaKeys/SoundPacks/`

Imports are copied through a private staging folder, validated again, and then moved into place. The original folder is not modified.

## File names

Use WAV, AIFF/AIF, CAF, or MP3 files. At least one regular key-down sound is required.

| Sound | Example names |
| --- | --- |
| Regular key down | `key1.wav`, `press_key_1.wav`, `press_standard_1.wav` |
| Space down | `space1.wav`, `press_space_1.wav` |
| Delete/Backspace down | `delete1.wav`, `press_back_1.wav` |
| Enter/Return down | `enter1.wav`, `press_enter_1.wav` |
| Mouse down | `mouse1.wav`, `click_1.wav` |
| Regular key release | `release_key_1.wav`, `key_up_1.wav` |
| Special-key release | `release_space_1.wav`, `release_back_1.wav`, `release_enter_1.wav` |

When a special recording is missing, MechaKeys falls back to the corresponding regular key recording. Release playback is optional and is enabled in Settings.

## Safety and performance limits

- At most 64 audio files and 25 MB total.
- At most 5 MB and two seconds per file.
- Nested folders, symbolic links, aliases, unsupported formats, scripts and executables are rejected or ignored.
- Sounds are converted to the app's 48 kHz mono playback format and preloaded when the pack is selected.

Only import recordings that you created or have permission to use and redistribute.
