import AppKit
import SwiftUI

private let mechaKeysIcon: NSImage = {
    guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
          let image = NSImage(contentsOf: url) else {
        return NSApplication.shared.applicationIconImage
    }
    return image
}()

@main
struct MechaKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { appDelegate.showsMenuBarIcon },
            set: { appDelegate.setShowsMenuBarIcon($0) }
        )) {
            MechaKeysPanel(appDelegate: appDelegate)
        } label: {
            Label(
                "MechaKeys",
                systemImage: appDelegate.soundEnabled ? "keyboard.fill" : "keyboard"
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}

private struct MechaKeysPanel: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var showingAbout = false

    var body: some View {
        Group {
            if showingAbout {
                aboutPage
            } else {
                controlsPage
            }
        }
        .padding(18)
        .frame(width: 340)
    }

    private var controlsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(nsImage: mechaKeysIcon)
                    .resizable()
                    .frame(width: 30, height: 30)
                Text("MechaKeys")
                    .font(.headline)
                Spacer()
                if appDelegate.bluetoothAudioConnected {
                    Label("Bluetooth Paused", systemImage: "speaker.slash.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if appDelegate.callMuteActive {
                    Label("Microphone Paused", systemImage: "mic.slash.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Label(
                        appDelegate.soundEnabled ? "Sounds On" : "Sounds Off",
                        systemImage: appDelegate.soundEnabled ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(appDelegate.soundEnabled ? .green : .red)
                }
            }

            Button {
                appDelegate.toggleSounds()
            } label: {
                Label(
                    primaryButtonTitle,
                    systemImage: primaryButtonIcon
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint((appDelegate.bluetoothAudioConnected || appDelegate.callMuteActive) ? .orange : (appDelegate.soundEnabled ? .red : .green))
            .controlSize(.large)
            .disabled(appDelegate.bluetoothAudioConnected || appDelegate.callMuteActive)

            if appDelegate.bluetoothAudioConnected {
                Text("Sounds resume automatically after all Bluetooth audio devices disconnect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if appDelegate.callMuteActive {
                Text("Sounds resume automatically when the microphone is no longer active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SWITCH SOUND")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Switch sound", selection: Binding(
                    get: { appDelegate.soundProfile },
                    set: { appDelegate.selectSoundProfile($0) }
                )) {
                    Text("Default").tag(KeyboardSoundProfile.standard)
                    Text("K Pro Red").tag(KeyboardSoundProfile.red)
                    Text("Alpaca").tag(KeyboardSoundProfile.alpaca)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!appDelegate.soundEnabled)

                Menu {
                    ForEach(appDelegate.customSoundPacks) { pack in
                        Button(pack.name) { appDelegate.selectCustomSoundPack(pack) }
                    }
                    if !appDelegate.customSoundPacks.isEmpty { Divider() }
                    Button("Import Sound Pack…") { appDelegate.importCustomSoundPack() }
                } label: {
                    Label(
                        appDelegate.soundProfile == .custom
                            ? appDelegate.selectedProfileName
                            : "Custom Sound Packs",
                        systemImage: "waveform.badge.plus"
                    )
                }
                .disabled(!appDelegate.soundEnabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("VOLUME")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(appDelegate.volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { appDelegate.volume },
                        set: { appDelegate.volume = $0 }
                    ), in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                .disabled(!appDelegate.soundEnabled)
            }

            Button("Play Test Sound", systemImage: "play.fill") {
                appDelegate.playTestSound()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(!appDelegate.soundEnabled)

            Divider()

            if appDelegate.hasKeyboardAccess {
                Label("Input Monitoring permission enabled", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Input Monitoring is required", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                    Text("Allow MechaKeys to hear keys while you type in other apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Request Access") {
                            appDelegate.requestKeyboardAccess()
                        }
                        Button("Open Settings") {
                            appDelegate.openKeyboardSettings()
                        }
                    }
                }
            }

            Divider()

            Toggle(isOn: Binding(
                get: { appDelegate.launchAtLogin },
                set: { appDelegate.setLaunchAtLogin($0) }
            )) {
                Label("Launch at Login", systemImage: "arrow.clockwise.circle.fill")
            }
            .toggleStyle(.switch)

            Text("MechaKeys lives in your MacBook notch. Hover the notch to access all controls anytime.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text("Version \(appDelegate.version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showingAbout = true
                    }
                } label: {
                    Label("About", systemImage: "info.circle")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))

                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        if appDelegate.bluetoothAudioConnected { return "Paused for Bluetooth Audio" }
        if appDelegate.callMuteActive { return "Paused While Microphone Is Active" }
        return appDelegate.soundEnabled ? "Turn Sounds Off" : "Turn Sounds On"
    }

    private var primaryButtonIcon: String {
        if appDelegate.bluetoothAudioConnected { return "speaker.slash.fill" }
        if appDelegate.callMuteActive { return "mic.slash.fill" }
        return appDelegate.soundEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill"
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showingAbout = false
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Version \(appDelegate.version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                Image(nsImage: mechaKeysIcon)
                    .resizable()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("About MechaKeys")
                        .font(.title3.weight(.bold))
                    Text("Mechanical sound feedback for your Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    featureRow(
                        icon: "info.circle.fill",
                        title: "Community build — not notarized",
                        description: "Free community software, locally signed and not notarized by Apple. macOS may require approval before opening and Input Monitoring permission after updates. Never disable Gatekeeper to run this app."
                    )
                    featureRow(
                        icon: "arrow.down.circle",
                        title: "Optional update checks",
                        description: "Use notch Settings → Check for Updates, or enable daily checks. Checks contact GitHub and show public releases. Downloads and installation stay manual; daily checks are off by default."
                    )
                    featureRow(
                        icon: "bolt.fill",
                        title: "Low-latency playback",
                        description: "Preloaded 48 kHz sounds, a warm audio engine, polyphonic playback, and stale-event dropping keep sound aligned with input."
                    )
                    featureRow(
                        icon: "keyboard.fill",
                        title: "Recorded sound profiles",
                        description: "Choose Default, K Pro Red, Alpaca, or validated custom sound packs."
                    )
                    featureRow(
                        icon: "slider.horizontal.3",
                        title: "Natural dynamics",
                        description: "Optional pitch variation, typing-speed response, repeat suppression and custom-pack release sounds."
                    )
                    featureRow(
                        icon: "mic.slash.fill",
                        title: "Microphone-aware",
                        description: "Optionally pauses while a microphone is active using events instead of continuous polling."
                    )
                    featureRow(
                        icon: "delete.left.fill",
                        title: "Special-key sounds",
                        description: "K Pro Red separates regular keys, Space, and mouse clicks. Alpaca also has distinct Delete/Backspace sounds. Default uses shared click variations."
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
                        title: "Idle-aware audio and hover",
                        description: "Audio sleeps after 30 seconds without input; wake-up never replays a backlog. Hover uses mouse events instead of continuous polling. Battery impact varies with usage."
                    )
                    featureRow(
                        icon: "menubar.rectangle",
                        title: "Menu-bar controls",
                        description: "Turn sounds on or off, change profiles and volume, play a test sound, and optionally launch at login."
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
                .padding(.trailing, 4)
            }
            .frame(maxHeight: 430)

            Divider()

            Text("Built by orstsm")
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private func featureRow(
        icon: String,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
