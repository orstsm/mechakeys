import AppKit
import SwiftUI

private let mechaKeysIcon: NSImage = {
    guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
          let image = NSImage(contentsOf: url) else {
        return NSApplication.shared.applicationIconImage
    }
    return image
}()

struct NotchView: View {
    @ObservedObject var model: ShelfModel
    @ObservedObject var appDelegate: AppDelegate

    private var targetWidth: CGFloat {
        if model.isExpanded {
            return model.activePage.expandedSize.width
        } else {
            return model.physicalNotchWidth
        }
    }

    private var targetHeight: CGFloat {
        if model.isExpanded {
            return model.activePage.expandedSize.height
        } else {
            return model.physicalNotchHeight
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black

            if model.isExpanded {
                Group {
                    switch model.activePage {
                    case .controls:
                        controlsPage
                    case .settings:
                        settingsPage
                    case .about:
                        aboutPage
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .foregroundStyle(.white)
            }
        }
        .clipShape(
            NotchShape(
                topCornerRadius: model.isExpanded ? 10 : 0,
                bottomCornerRadius: model.isExpanded ? 22 : 14
            )
        )
        .frame(width: targetWidth, height: targetHeight, alignment: .top)
        // Frame and visibility must change atomically with the AppKit panel.
        // Animating a separate SwiftUI frame can leave transparent hit regions.
        .transaction { $0.animation = nil }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
        .onTapGesture {
            if !model.isExpanded {
                model.openManually()
            }
        }
    }

    private var controlsPage: some View {
        VStack(spacing: 11) {
            header
            primaryButton
            profileButtons
            volumeControl

            if !appDelegate.hasKeyboardAccess {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Input Monitoring access needed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Grant") {
                        appDelegate.openKeyboardSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            actions
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard.fill")
                .font(.title3)
                .foregroundStyle(.red)

            Text("MechaKeys")
                .font(.headline.weight(.bold))

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(appDelegate.statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)

            Button {
                model.activePage = .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
            .help("MechaKeys Settings")
        }
    }

    private var primaryButton: some View {
        Button {
            appDelegate.toggleSounds()
        } label: {
            Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(primaryButtonColor)
        .disabled(appDelegate.bluetoothAudioConnected)
    }

    private var profileButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SWITCH SOUND")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.52))

            HStack(spacing: 4) {
                profileButton("Default", profile: .standard)
                profileButton("K Pro Red", profile: .red)
                profileButton("Alpaca", profile: .alpaca)
            }
            .padding(3)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func profileButton(_ name: String, profile: KeyboardSoundProfile) -> some View {
        let isSelected = appDelegate.soundProfile == profile
        return Button {
            appDelegate.selectSoundProfile(profile)
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(name)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : .white.opacity(0.68))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                isSelected ? Color.red : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!appDelegate.soundEnabled)
    }

    private var volumeControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.white.opacity(0.62))

            VolumeLevelSlider(
                value: Binding(
                    get: { appDelegate.volume },
                    set: { appDelegate.setVolume($0) }
                ),
                isEnabled: appDelegate.soundEnabled
            )

            Text("\(Int(appDelegate.volume * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.66))
                .frame(width: 35, alignment: .trailing)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Play Test", systemImage: "play.fill") {
                appDelegate.playTestSound()
            }
            .buttonStyle(.bordered)
            .disabled(!appDelegate.soundEnabled)

            Spacer()

            Button("About", systemImage: "info.circle") {
                model.activePage = .about
            }
            .buttonStyle(.bordered)

            Button("Quit", systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .font(.caption.weight(.semibold))
    }

    private var footer: some View {
        HStack {
            if let error = appDelegate.audioError {
                Label("Audio unavailable — try Play Test", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            } else if appDelegate.bluetoothAudioConnected {
                Label("Paused for BT audio", systemImage: "airpodspro")
                    .foregroundStyle(.orange)
            } else {
                Text("MechaKeys \(appDelegate.version)")
                    .foregroundStyle(.white.opacity(0.36))
            }

            Spacer()
        }
        .font(.caption2)
    }

    private var settingsPage: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    model.activePage = .controls
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
                Text("MechaKeys Settings")
                    .font(.headline.weight(.bold))
                Spacer()

                Button {
                    model.closeExplicitly()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { appDelegate.launchAtLogin },
                        set: { appDelegate.setLaunchAtLogin($0) }
                    )
                )
                .toggleStyle(.switch)
                .padding(12)

                Divider().overlay(.white.opacity(0.1))

                Toggle(
                    "Show Menu Bar Icon",
                    isOn: Binding(
                        get: { appDelegate.showsMenuBarIcon },
                        set: { appDelegate.setShowsMenuBarIcon($0) }
                    )
                )
                .toggleStyle(.switch)
                .padding(12)

                Divider().overlay(.white.opacity(0.1))

                Button {
                    model.activePage = .about
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.red)
                        Text("About MechaKeys & Features")
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(12)
                }
                .buttonStyle(.plain)
            }
            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 14))

            UpdateSettingsView(checker: appDelegate.updateChecker)

            Spacer(minLength: 0)

            HStack {
                Text("Version \(appDelegate.version)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                Spacer()
                Button("Quit MechaKeys", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    model.activePage = .controls
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
                Text("About MechaKeys")
                    .font(.headline.weight(.bold))
                Spacer()

                Button {
                    model.closeExplicitly()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Image(nsImage: mechaKeysIcon)
                    .resizable()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MechaKeys \(appDelegate.version)")
                        .font(.subheadline.weight(.bold))
                    Text("Mechanical sound feedback for your Mac")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            Divider().overlay(.white.opacity(0.12))

            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    featureRow(
                        icon: "bolt.fill",
                        title: "Low-latency playback",
                        description: "Preloaded 48 kHz sounds, a warm audio engine, polyphonic playback, and stale-event dropping keep sound aligned with input."
                    )
                    featureRow(
                        icon: "keyboard.fill",
                        title: "Recorded sound profiles",
                        description: "Choose Default, K Pro Red, or Alpaca, with natural variations so repeated keys do not sound identical."
                    )
                    featureRow(
                        icon: "delete.left.fill",
                        title: "Special-key sounds",
                        description: "Profiles provide distinct regular-key, Space, Delete/Backspace, and mouse-click recordings."
                    )
                    featureRow(
                        icon: "hifispeaker.2.fill",
                        title: "Spatial audio",
                        description: "Left-side keys pan left and right-side keys pan right for a subtle physical-keyboard effect."
                    )
                    featureRow(
                        icon: "computermouse.fill",
                        title: "Mouse click feedback",
                        description: "Left, right, and other mouse-button presses receive profile-matched click sounds."
                    )
                    featureRow(
                        icon: "airpodspro",
                        title: "Bluetooth-aware",
                        description: "Sounds pause when a Bluetooth headset, earphone, or speaker connects and resume automatically after it disconnects."
                    )
                    featureRow(
                        icon: "leaf.fill",
                        title: "Energy efficient",
                        description: "The audio engine sleeps after 30 seconds of inactivity and wakes without replaying a backlog of missed input."
                    )
                    featureRow(
                        icon: "display",
                        title: "Native MacBook Notch",
                        description: "Lives seamlessly in your MacBook notch. Hover to open controls, or optionally enable the menu bar icon."
                    )
                    featureRow(
                        icon: "lock.shield.fill",
                        title: "Private typing",
                        description: "Sounds work offline. No typed text or analytics are collected. Optional update checks contact GitHub; keyboard and mouse activity are never sent."
                    )
                    featureRow(
                        icon: "laptopcomputer",
                        title: "Universal Mac support",
                        description: "Runs natively on Apple Silicon and Intel Macs with macOS 13 or newer."
                    )
                }
                .padding(.trailing, 6)
            }
            .frame(maxHeight: 205)

            Divider().overlay(.white.opacity(0.12))

            Text("Built by orstsm")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func featureRow(
        icon: String,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var primaryButtonTitle: String {
        if appDelegate.bluetoothAudioConnected {
            return "Paused for BT Audio"
        }
        return appDelegate.soundEnabled ? "Turn Sounds Off" : "Turn Sounds On"
    }

    private var primaryButtonIcon: String {
        if appDelegate.bluetoothAudioConnected {
            return "speaker.slash.fill"
        }
        return appDelegate.soundEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill"
    }

    private var primaryButtonColor: Color {
        if appDelegate.bluetoothAudioConnected {
            return .orange
        }
        return appDelegate.soundEnabled ? .red : .green
    }

    private var statusColor: Color {
        if appDelegate.bluetoothAudioConnected { return .orange }
        if appDelegate.audioError != nil || (appDelegate.soundEnabled && !appDelegate.hasKeyboardAccess) { return .orange }
        return appDelegate.soundEnabled ? .green : .red
    }
}

private struct VolumeLevelSlider: View {
    @Binding var value: Double
    let isEnabled: Bool

    var body: some View {
        GeometryReader { geometry in
            let thumbSize: CGFloat = 18
            let usableWidth = max(0, geometry.size.width - thumbSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: 6)

                Capsule()
                    .fill(Color.red)
                    .frame(width: max(3, geometry.size.width * value), height: 6)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.32), radius: 2, y: 1)
                    .offset(x: usableWidth * value)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled, geometry.size.width > 0 else { return }
                        value = min(max(gesture.location.x / geometry.size.width, 0), 1)
                    }
            )
        }
        .frame(height: 20)
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityLabel("MechaKeys volume")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment:
                value = min(value + 0.05, 1)
            case .decrement:
                value = max(value - 0.05, 0)
            @unknown default:
                break
            }
        }
    }
}

/// Dynamic Notch shape inspired by BoringNotch:
/// Flat against the top screen bezel with outward-curving ears at the top
/// and rounded corners at the bottom.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 10, bottomCornerRadius: CGFloat = 22) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at top-left edge flush with screen bezel
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left ear curving down and inwards
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )

        // Left vertical edge down to bottom corner
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))

        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))

        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )

        // Right vertical edge up to top corner
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))

        // Top-right ear curving up and outwards to screen bezel
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )

        // Top flat edge closing back to top-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}
