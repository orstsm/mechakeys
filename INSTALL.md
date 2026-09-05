# Install MechaKeys

## Personal build

This universal build supports Apple Silicon and Intel Macs running macOS 13 or newer.

1. Download and unzip the versioned universal personal ZIP from your trusted release. If using the optional DMG, open it instead.
2. Drag **MechaKeys** into your **Applications** folder.
3. In Applications, Control-click MechaKeys and choose **Open** the first time.
4. Hover over the notch to open MechaKeys, then click **Grant** if Input Monitoring access is needed. Reopening MechaKeys from Finder also opens its controls. The menu-bar icon is optional.
5. Enable MechaKeys in **System Settings → Privacy & Security → Input Monitoring**.
6. Quit and reopen MechaKeys once if macOS requests it.
7. Enable **Launch at Login** if desired.

The personal build is ad-hoc signed. Only install it on Macs you control and only when it came from your own trusted GitHub repository. A seamless public download requires a Developer ID Application certificate and Apple notarization.

## GitHub

To build from source, run `zsh Tests/run.sh`, then `zsh build.sh --build-only`. Quit MechaKeys and run `zsh install.sh`. This installs into your user Applications folder with a recoverable previous-version backup; building by itself does not replace the installed app.

For a private repository, commit the contents of the source archive. Attach the universal app ZIP (or optional DMG) as a GitHub Release asset. On another Mac, download it from Releases and follow the steps above.

Do not present the personal DMG as a notarized public release. Once Developer ID credentials are available, use `release.sh` to produce the trusted release build.
