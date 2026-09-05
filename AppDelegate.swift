import AppKit
import CoreGraphics
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development" }
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var bluetoothAudioConnected = false
    @Published var volume: Double {
        didSet {
            let validated = Self.validVolume(volume)
            if volume != validated { volume = validated }
            audioController?.setVolume(Float(volume))
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }
    @Published var soundProfile: KeyboardSoundProfile {
        didSet {
            audioController?.setProfile(soundProfile)
            UserDefaults.standard.set(soundProfile.rawValue, forKey: "soundProfile")
        }
    }
    @Published private(set) var hasKeyboardAccess = false
    @Published private(set) var audioError: String?
    @Published private(set) var launchAtLogin = false
    @Published var showsMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showsMenuBarIcon, forKey: "showsMenuBarIcon")
        }
    }

    var statusText: String {
        if bluetoothAudioConnected { return "BT paused" }
        if audioError != nil { return "Audio unavailable" }
        if soundEnabled && !hasKeyboardAccess { return "Input unavailable" }
        return soundEnabled ? "Sounds on" : "Sounds off"
    }

    private var keyboardMonitor: GlobalKeyboardMonitor?
    private var accessCheckTimer: Timer?
    private var audioController: InputAudioController?
    private var bluetoothAudioMonitor: BluetoothAudioMonitor?
    private var userSoundEnabled: Bool

    private var notchWindowController: NotchWindowController?
    private var shelfModel: ShelfModel?

    override init() {
        let defaults = UserDefaults.standard
        let savedSoundEnabled = defaults.object(forKey: "soundEnabled") == nil
            ? true
            : defaults.bool(forKey: "soundEnabled")
        userSoundEnabled = savedSoundEnabled
        soundEnabled = savedSoundEnabled
        volume = Self.validVolume(defaults.object(forKey: "volume") as? Double ?? 0.72)
        let savedProfile = defaults.string(forKey: "soundProfile") ?? ""
        soundProfile = savedProfile == "K Pro Brown"
            ? .alpaca
            : (KeyboardSoundProfile(rawValue: savedProfile) ?? .standard)
        if savedProfile == "K Pro Brown" {
            defaults.set(KeyboardSoundProfile.alpaca.rawValue, forKey: "soundProfile")
        }
        showsMenuBarIcon = defaults.bool(forKey: "showsMenuBarIcon")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLoginManager.hardenExistingRegistration()
        refreshLaunchAtLoginStatus()

        let bluetoothMonitor = BluetoothAudioMonitor { [weak self] isConnected in
            Task { @MainActor in
                self?.handleAudioTopologyChange(bluetoothAudioConnected: isConnected)
            }
        }
        bluetoothAudioMonitor = bluetoothMonitor
        bluetoothAudioConnected = bluetoothMonitor.hasConnectedBluetoothAudioOutput
        soundEnabled = userSoundEnabled && !bluetoothAudioConnected

        do {
            let controller = try InputAudioController(
                volume: Float(volume),
                profile: soundProfile,
                idleTimeout: 30
            )
            audioController = controller
            controller.onHealthChange = { [weak self] error in
                Task { @MainActor in self?.audioError = error }
            }
            if soundEnabled {
                controller.warm()
            }
        } catch {
            audioError = error.localizedDescription
            presentAudioError(error)
        }

        bluetoothMonitor.start()

        let shelf = ShelfModel()
        self.shelfModel = shelf
        shelf.start()

        let notchController = NotchWindowController(model: shelf, appDelegate: self)
        self.notchWindowController = notchController
        notchController.show()
        shelf.openManually()

        updateKeyboardAccess()
        requestKeyboardAccessOnFirstLaunch()
        startAccessChecksIfNeeded()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshLaunchAtLoginStatus()
        updateKeyboardAccess()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        notchWindowController?.orderFront()
        shelfModel?.openManually()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        shelfModel?.stop()
        notchWindowController?.stop()
        keyboardMonitor?.stop()
        accessCheckTimer?.invalidate()
        bluetoothAudioMonitor?.stop()
        audioController?.stopSynchronously()
    }

    func playTestSound() {
        guard soundEnabled else { return }
        audioController?.playTestSound()
    }

    func toggleSounds() {
        userSoundEnabled.toggle()
        UserDefaults.standard.set(userSoundEnabled, forKey: "soundEnabled")
        applyPlaybackState(playTestOnEnable: true)
    }

    func setVolume(_ newVolume: Double) {
        volume = Self.validVolume(newVolume)
    }

    static func validVolume(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0.72
    }

    func selectSoundProfile(_ profile: KeyboardSoundProfile) {
        soundProfile = profile
        playTestSound()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            presentLaunchAtLoginError(error)
        }
    }

    func setShowsMenuBarIcon(_ shows: Bool) {
        showsMenuBarIcon = shows
    }

    func requestKeyboardAccess() {
        UserDefaults.standard.set(true, forKey: "didRequestInputMonitoring")
        hasKeyboardAccess = CGRequestListenEventAccess()
        updateKeyboardAccess()
        startAccessChecksIfNeeded()
    }

    func openKeyboardSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func requestKeyboardAccessOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: "didRequestInputMonitoring") else { return }
        requestKeyboardAccess()
    }

    private func startAccessChecksIfNeeded() {
        guard soundEnabled, !hasKeyboardAccess, accessCheckTimer == nil else { return }
        accessCheckTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.accessCheckTimer = nil
                self?.updateKeyboardAccess()
            }
        }
    }

    private func updateKeyboardAccess() {
        let accessGranted = CGPreflightListenEventAccess()
        hasKeyboardAccess = accessGranted

        if accessGranted {
            if soundEnabled {
                installKeyboardMonitorIfNeeded()
            }
        } else if keyboardMonitor != nil {
            keyboardMonitor?.stop()
            keyboardMonitor = nil
        }
        if hasKeyboardAccess {
            accessCheckTimer?.invalidate()
            accessCheckTimer = nil
        } else {
            startAccessChecksIfNeeded()
        }
    }

    private func installKeyboardMonitorIfNeeded() {
        guard keyboardMonitor == nil, let audioController else { return }

        let monitor = GlobalKeyboardMonitor { input in
            audioController.handle(input)
        }

        if monitor.start() {
            keyboardMonitor = monitor
        } else {
            hasKeyboardAccess = false
        }
    }

    private func handleAudioTopologyChange(bluetoothAudioConnected isConnected: Bool) {
        let bluetoothStateChanged = bluetoothAudioConnected != isConnected
        bluetoothAudioConnected = isConnected
        applyPlaybackState(
            playTestOnEnable: false,
            rebuildAudioRoute: !bluetoothStateChanged
        )
    }

    private func applyPlaybackState(
        playTestOnEnable: Bool,
        rebuildAudioRoute: Bool = false
    ) {
        let shouldEnable = userSoundEnabled && !bluetoothAudioConnected

        if shouldEnable != soundEnabled {
            soundEnabled = shouldEnable
            if shouldEnable {
                audioController?.warm()
                updateKeyboardAccess()
                startAccessChecksIfNeeded()
                if playTestOnEnable {
                    playTestSound()
                }
            } else {
                keyboardMonitor?.stop()
                keyboardMonitor = nil
                accessCheckTimer?.invalidate()
                accessCheckTimer = nil
                audioController?.suspend()
            }
        } else if shouldEnable && rebuildAudioRoute {
            audioController?.rebuildAudioRoute()
        }
    }

    private func presentAudioError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "MechaKeys could not start audio"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLogin = LaunchAtLoginManager.isEnabled
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Launch at Login could not be changed"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
