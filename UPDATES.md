# Publishing updates

Version 2.11.0 adds Settings → Check for Updates and an optional daily check. Daily checks are off by default. Updates are shown inside Settings; there are no system notifications or automatic installations. Users with 2.10.1 or older must manually install a version with the checker first.

Commit/push alone does not publish an app update. After testing and producing a Developer ID-signed, notarized ZIP, create a public GitHub Release in `orstsm/mechakeys`, attach the installer, tag it `vMAJOR.MINOR.PATCH` (for example `v2.11.0`), and mark it as the latest stable release. Do not mark it draft or prerelease. The bundle version must match the tag. The checker compares numeric versions, not lexical strings, and opens the release page so the user can read notes and choose the installer.

Private repositories are not supported by this unauthenticated checker. No tokens are embedded. A 404 means no public release exists or the repository is private; the app explains that rather than saying it is up to date. Network/rate-limit errors show a retry-later message. Daily attempts are limited to approximately once per 24 hours while the app runs, with no catch-up backlog after sleep. Manual checks are limited to one start per 30 seconds. Turning daily checks off cancels future scheduled checks; an already-running check may finish.

GitHub API reference: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
