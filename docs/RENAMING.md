# NotchHarbor rename and compatibility

NotchHarbor 2.15.0 is the continuation of MechaKeys, not a second app. MechaKeys is now the name of its keyboard-sound feature. Spotify and camera features are not yet implemented.

## Intentional legacy identifiers

- Bundle ID and login-item identity: `com.mechakeys.app`. Keep these stable so preferences remain in the existing defaults domain.
- Custom recordings: `~/Library/Application Support/MechaKeys/SoundPacks/`. The rename never moves or deletes these files.
- Existing diagnostic labels and signing environment variables are retained for compatibility. Historical release notes and battery measurements retain their original product/version names.
- App/executable/download name: `NotchHarbor`. Local repository folder: `notchharbor`. Git remote after the online rename: `https://github.com/orstsm/notchharbor.git`.

Keeping the bundle ID reduces identity changes but does not guarantee preservation of macOS privacy grants after an ad-hoc rebuild. Check Input Monitoring, Launch at Login, both presentation modes and sleep recovery on the installed app.

## Update transition

The updater uses `https://api.github.com/repositories/1356119654/releases/latest`, the existing repository's immutable ID. No redirects are allowed. Release pages are restricted to HTTPS on github.com, owner `orstsm`, repositories `notchharbor` or `mechakeys`, and the exact reported numeric version tag. Redirects, arbitrary GitHub repositories and modified paths are not accepted.

Pre-2.15.0 installations use the old name-based endpoint and reject redirects. Publishing a new release cannot change already-installed code. Those users need one manual download after the rename. Do not promise seamless automatic migration and do not create a new repository at the old name (that would supersede GitHub's redirects).

## Installation and rollback

Quit the running app first. Build, then run `zsh install.sh`. It installs `~/Applications/NotchHarbor.app`; verifies and moves the exact sibling `MechaKeys.app` into `.notchharbor-install-UUID.noindex/MechaKeys.bundle-backup`; and keeps any prior NotchHarbor version as `previous.bundle-backup`. It does not touch sound packs or preferences. To restore, quit NotchHarbor and restore the saved bundle under its original `.app` name. Do not run a backup alongside the active app.

Only a running-process check on the real desktop can establish that the old copy is stopped. Sandboxed diagnostics may not enumerate other applications; do not infer that no app is running from an empty sandboxed list.

## GitHub Desktop

After the local directory move, use File → Add Local Repository and choose the `notchharbor` folder (or Locate if Desktop reports the old path missing). This is the same `.git` history, not a fresh clone. Do not initialize or publish a second repository. Commit changes when reviewed; push a new version tag only when ready to publish.
