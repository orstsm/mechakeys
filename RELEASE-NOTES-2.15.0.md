# NotchHarbor 2.15.0 — MechaKeys, renamed

- Renames the app, controls, About pages and download bundles to NotchHarbor. MechaKeys remains the keyboard-sound feature.
- Preserves the existing application identifier, preferences and custom sound-pack location. Sound playback, hover behavior and sleep-recovery logic are unchanged in this branding release.
- Update checks use the existing GitHub repository's stable numeric ID, with no network redirects. Release links accept only the old and new repository names and the exact reported version.
- The local installer verifies both app identities and signatures, installs NotchHarbor and retains the old MechaKeys app in a hidden recovery folder instead of leaving two installed applications.
- Existing legacy login entries are repointed to the renamed app while macOS login-item approval is pending.
- New minimalist notch icon. Spotify controls and the camera mirror are planned, not included in this release.

## Upgrading

Older MechaKeys update checkers reject repository redirects and cannot be patched remotely. After the GitHub rename, download this release manually from the NotchHarbor repository. Quit MechaKeys, install NotchHarbor into the same Applications folder, then remove the old MechaKeys app once the new app is verified. Do not remove your Application Support data.

Community builds are ad-hoc signed and not notarized by Apple. Input Monitoring or Launch at Login may need approval again. Downloads and installation remain manual. Existing audio rights and restrictions are unchanged by the rename.
