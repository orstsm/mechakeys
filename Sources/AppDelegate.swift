import AppKit
import CoreGraphics
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let updateChecker = UpdateChecker(currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0")
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development" }
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var bluetoothAudioConnected = false
    @Published private(set) var microphoneActive = false
    @Published private(set) var customSoundPacks: [CustomSoundPack]
    @Published private(set) var selectedCustomPackID: String?
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
    @Published var pitchVariationEnabled: Bool {
        didSet {
            audioController?.setPitchVariationEnabled(pitchVariationEnabled)
            UserDefaults.standard.set(pitchVariationEnabled, forKey: "pitchVariationEnabled")
        }
    }
    @Published var typingDynamicsEnabled: Bool {
        didSet {
            audioController?.setTypingDynamicsEnabled(typingDynamicsEnabled)
            UserDefaults.standard.set(typingDynamicsEnabled, forKey: "typingDynamicsEnabled")
        }
    }
    @Published var suppressKeyRepeat: Bool {
        didSet {
            keyboardMonitor?.suppressKeyRepeat = suppressKeyRepeat
            UserDefaults.standard.set(suppressKeyRepeat, forKey: "suppressKeyRepeat")
        }
    }
    @Published var releaseSoundsEnabled: Bool {
        didSet {
            audioController?.setReleaseSoundsEnabled(releaseSoundsEnabled)
            UserDefaults.standard.set(releaseSoundsEnabled, forKey: "releaseSoundsEnabled")
        }
    }
    @Published var muteDuringCalls: Bool {
        didSet {
            UserDefaults.standard.set(muteDuringCalls, forKey: "muteDuringCalls")
            configureMicrophoneMonitoring()
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
        if callMuteActive { return "Mic paused" }
        if audioError != nil { return "Audio unavailable" }
        if soundEnabled && !hasKeyboardAccess { return "Input unavailable" }
        return soundEnabled ? "Sounds on" : "Sounds off"
    }

    private var keyboardMonitor: GlobalKeyboardMonitor?
    private var accessCheckTimer: Timer?
    private var audioController: InputAudioController?
    private var bluetoothAudioMonitor: BluetoothAudioMonitor?
    private var microphoneActivityMonitor: MicrophoneActivityMonitor?
    private let customSoundPackLibrary: CustomSoundPackLibrary?
    private var userSoundEnabled: Bool

    private var notchWindowController: NotchWindowController?
    private var shelfModel: ShelfModel?

    var callMuteActive: Bool { muteDuringCalls && microphoneActive }

    var selectedProfileName: String {
        if soundProfile == .custom,
           let id = selectedCustomPackID,
           let pack = customSoundPacks.first(where: { $0.id == id }) {
            return pack.name
        }
        return soundProfile.rawValue
    }

    override init() {
        let defaults = UserDefaults.standard
        let library = try? CustomSoundPackLibrary()
        let restoredCustomPacks = library?.availablePacks() ?? []
        let restoredCustomPackID = defaults.string(forKey: "selectedCustomPackID")
        customSoundPackLibrary = library
        customSoundPacks = restoredCustomPacks
        selectedCustomPackID = restoredCustomPackID
        let savedSoundEnabled = defaults.object(forKey: "soundEnabled") == nil
            ? true
            : defaults.bool(forKey: "soundEnabled")
        userSoundEnabled = savedSoundEnabled
        soundEnabled = savedSoundEnabled
        volume = Self.validVolume(defaults.object(forKey: "volume") as? Double ?? 0.72)
        let savedProfile = defaults.string(forKey: "soundProfile") ?? ""
        let restoredProfile = savedProfile == "K Pro Brown"
            ? .alpaca
            : (KeyboardSoundProfile(rawValue: savedProfile) ?? .standard)
        if restoredProfile == .custom,
           let restoredCustomPackID,
           restoredCustomPacks.contains(where: { $0.id == restoredCustomPackID }) {
            soundProfile = .custom
        } else {
            soundProfile = restoredProfile == .custom ? .standard : restoredProfile
            if restoredProfile == .custom { selectedCustomPackID = nil }
        }
        pitchVariationEnabled = Self.savedBool(defaults, key: "pitchVariationEnabled", defaultValue: true)
        typingDynamicsEnabled = Self.savedBool(defaults, key: "typingDynamicsEnabled", defaultValue: true)
        suppressKeyRepeat = Self.savedBool(defaults, key: "suppressKeyRepeat", defaultValue: true)
        releaseSoundsEnabled = defaults.bool(forKey: "releaseSoundsEnabled")
        muteDuringCalls = Self.savedBool(defaults, key: "muteDuringCalls", defaultValue: true)
        if savedProfile == "K Pro Brown" {
            defaults.set(KeyboardSoundProfile.alpaca.rawValue, forKey: "soundProfile")
        }
        showsMenuBarIcon = defaults.bool(forKey: "showsMenuBarIcon")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateChecker.start()
        LaunchAtLoginManager.hardenExistingRegistration()
        refreshLaunchAtLoginStatus()

        let bluetoothMonitor = BluetoothAudioMonitor { [weak self] isConnected in
            Task { @MainActor in
                self?.handleAudioTopologyChange(bluetoothAudioConnected: isConnected)
            }
        }
        bluetoothAudioMonitor = bluetoothMonitor
        bluetoothAudioConnected = bluetoothMonitor.hasConnectedBluetoothAudioOutput
        let microphoneMonitor = MicrophoneActivityMonitor { [weak self] isActive in
            Task { @MainActor in self?.handleMicrophoneActivityChange(isActive) }
        }
        microphoneActivityMonitor = microphoneMonitor
        microphoneActive = muteDuringCalls && microphoneMonitor.isMicrophoneActive
        soundEnabled = PlaybackPolicy.shouldEnable(
            userEnabled: userSoundEnabled,
            bluetoothAudioConnected: bluetoothAudioConnected,
            muteDuringCalls: muteDuringCalls,
            microphoneActive: microphoneActive
        )

        do {
            let controller = try InputAudioController(
                volume: Float(volume),
                profile: soundProfile,
                idleTimeout: 30
            )
            audioController = controller
            controller.setPitchVariationEnabled(pitchVariationEnabled)
            controller.setTypingDynamicsEnabled(typingDynamicsEnabled)
            controller.setReleaseSoundsEnabled(releaseSoundsEnabled)
            if soundProfile == .custom,
               let id = selectedCustomPackID,
               let pack = customSoundPacks.first(where: { $0.id == id }) {
                controller.setCustomSoundPack(pack) { [weak self] error in
                    guard let error else { return }
                    Task { @MainActor in self?.audioError = error.localizedDescription }
                }
            }
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
        if muteDuringCalls { microphoneMonitor.start() }

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
        updateChecker.stop()
        shelfModel?.stop()
        notchWindowController?.stop()
        keyboardMonitor?.stop()
        accessCheckTimer?.invalidate()
        bluetoothAudioMonitor?.stop()
        microphoneActivityMonitor?.stop()
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
        guard profile != .custom else { return }
        selectedCustomPackID = nil
        UserDefaults.standard.removeObject(forKey: "selectedCustomPackID")
        audioController?.setCustomSoundPack(nil) { _ in }
        soundProfile = profile
        playTestSound()
    }

    func selectCustomSoundPack(_ pack: CustomSoundPack) {
        audioController?.setCustomSoundPack(pack) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.audioError = error.localizedDescription
                    self.presentSoundPackError(error)
                    return
                }
                self.selectedCustomPackID = pack.id
                UserDefaults.standard.set(pack.id, forKey: "selectedCustomPackID")
                self.soundProfile = .custom
                self.audioError = nil
                self.playTestSound()
            }
        }
    }

    func importCustomSoundPack() {
        guard let customSoundPackLibrary else { return }
        let panel = NSOpenPanel()
        panel.title = "Import MechaKeys Sound Pack"
        panel.message = "Choose a folder with WAV, AIFF, CAF, or MP3 files. Regular key sounds are required."
        panel.prompt = "Import"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        NSApplication.shared.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            let pack = try customSoundPackLibrary.importPack(from: sourceURL)
            customSoundPacks = customSoundPackLibrary.availablePacks()
            selectCustomSoundPack(pack)
        } catch {
            presentSoundPackError(error)
        }
    }

    func setPitchVariationEnabled(_ enabled: Bool) { pitchVariationEnabled = enabled }
    func setTypingDynamicsEnabled(_ enabled: Bool) { typingDynamicsEnabled = enabled }
    func setSuppressKeyRepeat(_ enabled: Bool) { suppressKeyRepeat = enabled }
    func setReleaseSoundsEnabled(_ enabled: Bool) { releaseSoundsEnabled = enabled }
    func setMuteDuringCalls(_ enabled: Bool) { muteDuringCalls = enabled }

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
        monitor.suppressKeyRepeat = suppressKeyRepeat

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

    private func handleMicrophoneActivityChange(_ active: Bool) {
        microphoneActive = active
        applyPlaybackState(playTestOnEnable: false)
    }

    private func configureMicrophoneMonitoring() {
        guard let microphoneActivityMonitor else { return }
        if muteDuringCalls {
            microphoneActive = microphoneActivityMonitor.isMicrophoneActive
            microphoneActivityMonitor.start()
        } else {
            microphoneActivityMonitor.stop()
            microphoneActive = false
        }
        applyPlaybackState(playTestOnEnable: false)
    }

    private func applyPlaybackState(
        playTestOnEnable: Bool,
        rebuildAudioRoute: Bool = false
    ) {
        let shouldEnable = PlaybackPolicy.shouldEnable(
            userEnabled: userSoundEnabled,
            bluetoothAudioConnected: bluetoothAudioConnected,
            muteDuringCalls: muteDuringCalls,
            microphoneActive: microphoneActive
        )

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

    private func presentSoundPackError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "The sound pack could not be imported"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func savedBool(
        _ defaults: UserDefaults,
        key: String,
        defaultValue: Bool
    ) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }
}
