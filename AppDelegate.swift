import AppKit
import CoreGraphics
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var bluetoothAudioConnected = false
    @Published var volume: Double {
        didSet {
            audioController?.setVolume(Float(volume))
            UserDefaults.standard.set(volume, forKey: "volume")
            broadcastNotchShelfState()
        }
    }
    @Published var soundProfile: KeyboardSoundProfile {
        didSet {
            audioController?.setProfile(soundProfile)
            UserDefaults.standard.set(soundProfile.rawValue, forKey: "soundProfile")
            broadcastNotchShelfState()
        }
    }
    @Published private(set) var hasKeyboardAccess = false
    @Published private(set) var launchAtLogin = false

    private var keyboardMonitor: GlobalKeyboardMonitor?
    private var accessCheckTimer: Timer?
    private var audioController: InputAudioController?
    private var bluetoothAudioMonitor: BluetoothAudioMonitor?
    private var userSoundEnabled: Bool
    private var notchShelfObservers: [NSObjectProtocol] = []

    private static let notchShelfCommandNotification = Notification.Name(
        "com.orstsm.mechakeys.command"
    )
    private static let notchShelfStateNotification = Notification.Name(
        "com.orstsm.mechakeys.state"
    )

    override init() {
        let defaults = UserDefaults.standard
        let savedSoundEnabled = defaults.object(forKey: "soundEnabled") == nil
            ? true
            : defaults.bool(forKey: "soundEnabled")
        userSoundEnabled = savedSoundEnabled
        soundEnabled = savedSoundEnabled
        volume = defaults.object(forKey: "volume") as? Double ?? 0.72
        let savedProfile = defaults.string(forKey: "soundProfile") ?? ""
        soundProfile = savedProfile == "K Pro Brown"
            ? .alpaca
            : (KeyboardSoundProfile(rawValue: savedProfile) ?? .standard)
        if savedProfile == "K Pro Brown" {
            defaults.set(KeyboardSoundProfile.alpaca.rawValue, forKey: "soundProfile")
        }
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
            if soundEnabled {
                controller.warm()
            }
        } catch {
            presentAudioError(error)
        }

        bluetoothMonitor.start()

        installNotchShelfBridge()

        updateKeyboardAccess()
        requestKeyboardAccessOnFirstLaunch()
        startAccessChecksIfNeeded()
        broadcastNotchShelfState()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshLaunchAtLoginStatus()
        updateKeyboardAccess()
    }

    func applicationWillTerminate(_ notification: Notification) {
        broadcastNotchShelfState(running: false)
        notchShelfObservers.forEach {
            DistributedNotificationCenter.default().removeObserver($0)
        }
        notchShelfObservers.removeAll()
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
        accessCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateKeyboardAccess()
            }
        }
    }

    private func updateKeyboardAccess() {
        let accessGranted = CGPreflightListenEventAccess()
        let accessChanged = hasKeyboardAccess != accessGranted
        hasKeyboardAccess = accessGranted

        if accessGranted {
            accessCheckTimer?.invalidate()
            accessCheckTimer = nil
            if soundEnabled {
                installKeyboardMonitorIfNeeded()
            }
        } else if keyboardMonitor != nil {
            keyboardMonitor?.stop()
            keyboardMonitor = nil
        }

        if accessChanged {
            broadcastNotchShelfState()
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

        broadcastNotchShelfState()
    }

    private func installNotchShelfBridge() {
        let observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.notchShelfCommandNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleNotchShelfCommand(notification.userInfo)
            }
        }
        notchShelfObservers.append(observer)
    }

    private func handleNotchShelfCommand(_ information: [AnyHashable: Any]?) {
        guard let information,
              information["sender"] as? String == "com.orstsm.notchshelf",
              let command = information["command"] as? String
        else { return }

        switch command {
        case "requestState":
            break
        case "toggleSounds":
            toggleSounds()
        case "setVolume":
            if let value = information["volume"] as? Double {
                volume = min(max(value, 0), 1)
            } else if let number = information["volume"] as? NSNumber {
                volume = min(max(number.doubleValue, 0), 1)
            }
        case "setProfile":
            if let rawProfile = information["profile"] as? String,
               let profile = KeyboardSoundProfile(rawValue: rawProfile) {
                selectSoundProfile(profile)
            }
        case "playTestSound":
            playTestSound()
        case "quit":
            broadcastNotchShelfState(running: false)
            NSApplication.shared.terminate(nil)
            return
        default:
            return
        }

        broadcastNotchShelfState()
    }

    private func broadcastNotchShelfState(running: Bool = true) {
        DistributedNotificationCenter.default().postNotificationName(
            Self.notchShelfStateNotification,
            object: nil,
            userInfo: [
                "running": running,
                "soundEnabled": soundEnabled,
                "soundPreferenceEnabled": userSoundEnabled,
                "bluetoothPaused": bluetoothAudioConnected,
                "hasInputPermission": hasKeyboardAccess,
                "volume": volume,
                "profile": soundProfile.rawValue
            ],
            deliverImmediately: true
        )
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
