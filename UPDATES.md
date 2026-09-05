# Publishing updates

Version 2.11.0 adds Settings → Check for Updates and an optional daily check. Daily checks are off by default. Updates are shown inside Settings; there are no system notifications or automatic installations. Users with 2.10.1 or older must manually install a version with the checker first.

## Publish from GitHub Desktop

Regular commits and pushes do not publish app downloads. The community release workflow runs only when you push a version tag to `orstsm/mechakeys`.

1. Prepare and test the update. Set `CFBundleShortVersionString` in Info.plist to the new version, increment `CFBundleVersion`, and add `RELEASE-NOTES-MAJOR.MINOR.PATCH.md`. Use a version higher than the previous release. Confirm redistribution rights for all included audio/assets.
2. In GitHub Desktop, review and commit all intended changes, including the workflow and packaging script. For this update, use **Prepare MechaKeys 2.11.1 community release**. Push origin.
3. In **History**, right-click that release commit → **Create Tag**, enter `v2.11.1` (use the new version next time), then **Push origin**. This tag is the explicit instruction to publish that exact commit. Do not tag an older commit that lacks the workflow.
4. GitHub Actions checks the tag/version and release notes, runs tests, builds Apple Silicon + Intel, verifies the signature and ZIP, and publishes a Release with the community app ZIP, installation instructions and SHA-256 checksums. Allow several minutes; pushing a tag alone does not mean the build succeeded.
5. If needed, **Repository → View on GitHub → Actions** shows progress/errors. Check the Releases page before announcing the download. GitHub may still require website sign-in for troubleshooting or repository settings, but normal release publishing is triggered from Desktop.

No Apple Developer account, personal access token, or signing secret is required for this workflow. It uses GitHub's short-lived built-in token with repository-content write permission to publish the Release; checkout does not retain credentials. GitHub Actions must be enabled and repository/organization policy must permit the workflow. Private repositories can have Actions billing limits and are not supported by the app's public update checker.

**Community downloads are ad-hoc signed, not Developer ID-signed or Apple-notarized.** Release notes always include this warning. macOS may block opening or require explicit per-app approval and renewed Input Monitoring permission. Never disable Gatekeeper. For a future notarized release, use `release.sh` with your own Developer ID credentials instead.

The workflow will not overwrite an existing release. If publishing fails after creating a draft, inspect that draft and its assets on GitHub before retrying; do not move/reuse a published version tag. Build/test failures before publication leave no downloadable release. For a local packaging check without publishing, run `zsh package-community.sh v2.11.1`.

The app checker compares numeric versions, ignores drafts/prereleases, and opens the public release page so users can read notes and choose the ZIP. It does not install updates automatically. A failed workflow does not notify app users of a new version.

Private repositories are not supported by this unauthenticated checker. No tokens are embedded. A 404 means no public release exists or the repository is private; the app explains that rather than saying it is up to date. Network/rate-limit errors show a retry-later message. Daily attempts are limited to approximately once per 24 hours while the app runs, with no catch-up backlog after sleep. Manual checks are limited to one start per 30 seconds. Turning daily checks off cancels future scheduled checks; an already-running check may finish.

GitHub API reference: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
