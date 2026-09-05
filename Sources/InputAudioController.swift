import Foundation

protocol InputAudioEngine: AnyObject {
    var volume: Float { get set }
    var profile: KeyboardSoundProfile { get set }

    func start() throws
    func playKeyboard(keyCode: UInt16)
    func playMouse(button: Int64)
    func suspend()
    func stop()
}

extension KeyboardAudioEngine: InputAudioEngine {}

final class InputAudioController {
    private enum Phase {
        case sleeping
        case waking
        case ready
    }

    private let queue = DispatchQueue(
        label: "com.mechakeys.audio-input",
        qos: .userInteractive
    )
    private let stateLock = NSLock()
    private let engine: any InputAudioEngine
    private let idleTimeout: TimeInterval
    var onHealthChange: ((String?) -> Void)?
    private let maximumWarmEventDelayNanoseconds: UInt64 = 25_000_000
    private let timingLogEnabled = ProcessInfo.processInfo.environment["MECHAKEYS_TIMING_LOG"] == "1"

    private var phase: Phase = .sleeping
    private var generation: UInt64 = 0
    private var pendingWakeKey: UInt16?
    private var lastInputNanoseconds = DispatchTime.now().uptimeNanoseconds
    private var wakeStartedNanoseconds = DispatchTime.now().uptimeNanoseconds
    private let idleTimer: DispatchSourceTimer

    init(
        volume: Float,
        profile: KeyboardSoundProfile,
        idleTimeout: TimeInterval = 30
    ) throws {
        let engine = try KeyboardAudioEngine()
        self.engine = engine
        engine.volume = volume
        engine.profile = profile
        self.idleTimeout = idleTimeout

        let timer = DispatchSource.makeTimerSource(queue: queue)
        idleTimer = timer
        timer.setEventHandler { [weak self] in
            self?.idleTimerFired()
        }
        timer.schedule(deadline: .distantFuture)
        timer.resume()
    }

    init(
        engine: any InputAudioEngine,
        volume: Float,
        profile: KeyboardSoundProfile,
        idleTimeout: TimeInterval
    ) {
        self.engine = engine
        engine.volume = volume
        engine.profile = profile
        self.idleTimeout = idleTimeout

        let timer = DispatchSource.makeTimerSource(queue: queue)
        idleTimer = timer
        timer.setEventHandler { [weak self] in
            self?.idleTimerFired()
        }
        timer.schedule(deadline: .distantFuture)
        timer.resume()
    }

    func warm() {
        var shouldStart = false
        stateLock.lock()
        if phase == .sleeping {
            phase = .waking
            pendingWakeKey = nil
            let now = DispatchTime.now().uptimeNanoseconds
            lastInputNanoseconds = now
            wakeStartedNanoseconds = now
            shouldStart = true
        }
        let ticket = generation
        stateLock.unlock()

        if shouldStart {
            queue.async { [weak self] in
                self?.finishWake(ticket: ticket)
            }
        }
    }

    func handle(_ input: GlobalInputEvent) {
        let eventTime = DispatchTime.now().uptimeNanoseconds
        var shouldStart = false
        var shouldPlayImmediately = false

        stateLock.lock()
        lastInputNanoseconds = eventTime
        switch phase {
        case .sleeping:
            phase = .waking
            wakeStartedNanoseconds = eventTime
            if case .keyDown(let keyCode) = input {
                pendingWakeKey = keyCode
            } else {
                pendingWakeKey = nil
            }
            shouldStart = true

        case .waking:
            if case .keyDown(let keyCode) = input {
                // Keep one key only. Mouse clicks are deliberately discarded during wake-up.
                pendingWakeKey = keyCode
            } else {
                timingLog("MechaKeys discarded a mouse click during audio wake-up")
            }

        case .ready:
            shouldPlayImmediately = true
        }
        let ticket = generation
        stateLock.unlock()

        if shouldStart {
            queue.async { [weak self] in
                self?.finishWake(ticket: ticket)
            }
        } else if shouldPlayImmediately {
            queue.async { [weak self] in
                self?.playWarmEvent(input, eventTime: eventTime, ticket: ticket)
            }
        }
    }

    func playTestSound() {
        handle(.keyDown(0))
    }

    func setVolume(_ volume: Float) {
        queue.async { [weak self] in
            self?.engine.volume = volume
        }
    }

    func setProfile(_ profile: KeyboardSoundProfile) {
        queue.async { [weak self] in
            self?.engine.profile = profile
        }
    }

    func suspend() {
        stateLock.lock()
        generation &+= 1
        phase = .sleeping
        pendingWakeKey = nil
        stateLock.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            self.idleTimer.schedule(deadline: .distantFuture)
            self.engine.suspend()
        }
    }

    func rebuildAudioRoute() {
        suspend()
        warm()
    }

    func stopSynchronously() {
        stateLock.lock()
        generation &+= 1
        phase = .sleeping
        pendingWakeKey = nil
        stateLock.unlock()

        queue.sync {
            idleTimer.schedule(deadline: .distantFuture)
            engine.stop()
        }
    }

    private func finishWake(ticket: UInt64) {
        stateLock.lock()
        let valid = ticket == generation && phase == .waking
        stateLock.unlock()
        guard valid else { return }
        do {
            try engine.start()
        } catch {
            NSLog("MechaKeys could not start audio: %@", error.localizedDescription)
            onHealthChange?(error.localizedDescription)
            stateLock.lock()
            if ticket == generation {
                phase = .sleeping
                pendingWakeKey = nil
            }
            stateLock.unlock()
            return
        }

        var keyToPlay: UInt16?
        var wakeStarted: UInt64 = 0
        stateLock.lock()
        if ticket == generation && phase == .waking {
            phase = .ready
            keyToPlay = pendingWakeKey
            pendingWakeKey = nil
            wakeStarted = wakeStartedNanoseconds
        }
        let stillReady = ticket == generation && phase == .ready
        stateLock.unlock()

        guard stillReady else {
            engine.suspend()
            return
        }
        onHealthChange?(nil)

        if timingLogEnabled {
            let now = DispatchTime.now().uptimeNanoseconds
            let wakeDelay = now >= wakeStarted ? now - wakeStarted : 0
            timingLog(
                String(
                    format: "MechaKeys audio wake completed in %.2f ms; coalesced key: %@",
                    Double(wakeDelay) / 1_000_000,
                    keyToPlay == nil ? "none" : "yes"
                )
            )
        }

        if let keyToPlay {
            engine.playKeyboard(keyCode: keyToPlay)
        }
        scheduleIdleTimerFromLastInput()
    }

    private func playWarmEvent(_ input: GlobalInputEvent, eventTime: UInt64, ticket: UInt64) {
        stateLock.lock()
        let stillReady = ticket == generation && phase == .ready
        stateLock.unlock()
        guard stillReady else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        let delay = now >= eventTime ? now - eventTime : 0
        if delay <= maximumWarmEventDelayNanoseconds {
            switch input {
            case .keyDown(let keyCode):
                engine.playKeyboard(keyCode: keyCode)
            case .mouseDown(let button):
                engine.playMouse(button: button)
            }
        } else if timingLogEnabled {
            timingLog(String(format: "MechaKeys dropped a stale input sound delayed by %.2f ms", Double(delay) / 1_000_000))
        }

        if timingLogEnabled {
            timingLog(String(format: "MechaKeys warm input scheduling delay: %.2f ms", Double(delay) / 1_000_000))
        }
        scheduleIdleTimerFromLastInput()
    }

    private func scheduleIdleTimerFromLastInput() {
        stateLock.lock()
        let lastInput = lastInputNanoseconds
        stateLock.unlock()

        let now = DispatchTime.now().uptimeNanoseconds
        let timeoutNanoseconds = UInt64(idleTimeout * 1_000_000_000)
        let elapsed = now >= lastInput ? now - lastInput : 0
        let remaining = elapsed >= timeoutNanoseconds ? 0 : timeoutNanoseconds - elapsed
        idleTimer.schedule(deadline: .now() + .nanoseconds(Int(remaining)), leeway: .milliseconds(250))
    }

    private func idleTimerFired() {
        let now = DispatchTime.now().uptimeNanoseconds
        let timeoutNanoseconds = UInt64(idleTimeout * 1_000_000_000)

        stateLock.lock()
        let elapsed = now >= lastInputNanoseconds ? now - lastInputNanoseconds : 0
        guard phase == .ready else {
            stateLock.unlock()
            idleTimer.schedule(deadline: .distantFuture)
            return
        }
        guard elapsed >= timeoutNanoseconds else {
            stateLock.unlock()
            scheduleIdleTimerFromLastInput()
            return
        }
        phase = .sleeping
        pendingWakeKey = nil
        stateLock.unlock()

        idleTimer.schedule(deadline: .distantFuture)
        engine.suspend()
    }

    private func timingLog(_ message: String) {
        guard timingLogEnabled, let data = (message + "\n").data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }

    deinit {
        idleTimer.setEventHandler {}
        idleTimer.cancel()
    }
}
