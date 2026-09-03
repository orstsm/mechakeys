# Install MechaKeys

## Personal build

This universal build supports Apple Silicon and Intel Macs running macOS 13 or newer.

1. Download and unzip `MechaKeys-2.7.0-universal-personal.zip`. If using the optional DMG, open it instead.
2. Drag **MechaKeys** into your **Applications** folder.
3. In Applications, Control-click MechaKeys and choose **Open** the first time.
4. Open the keyboard icon in the menu bar and click **Request Access**.
5. Enable MechaKeys in **System Settings → Privacy & Security → Input Monitoring**.
6. Quit and reopen MechaKeys once if macOS requests it.
7. Enable **Launch at Login** if desired.

The personal build is ad-hoc signed. Only install it on Macs you control and only when it came from your own trusted GitHub repository. A seamless public download requires a Developer ID Application certificate and Apple notarization.

## GitHub

For a private repository, commit the contents of the source archive. Attach the universal app ZIP (or optional DMG) as a GitHub Release asset. On another Mac, download it from Releases and follow the steps above.

Do not present the personal DMG as a notarized public release. Once Developer ID credentials are available, use `release.sh` to produce the trusted release build.
