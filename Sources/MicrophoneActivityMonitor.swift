import CoreAudio
import Foundation

/// Event-driven microphone activity observation. This intentionally avoids a
/// repeating poll; Core Audio wakes the queue only when devices or run state change.
final class MicrophoneActivityMonitor {
    typealias StateHandler = (Bool) -> Void

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let queue = DispatchQueue(label: "com.mechakeys.microphone-activity", qos: .utility)
    private let queueKey = DispatchSpecificKey<Bool>()
    private let stateHandler: StateHandler
    private var devicesListener: AudioObjectPropertyListenerBlock?
    private var deviceListeners: [AudioDeviceID: AudioObjectPropertyListenerBlock] = [:]
    private var pendingEvaluation: DispatchWorkItem?
    private var lastReportedState: Bool?
    private var isStarted = false
    private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    init(stateHandler: @escaping StateHandler) {
        self.stateHandler = stateHandler
        queue.setSpecific(key: queueKey, value: true)
    }

    var isMicrophoneActive: Bool {
        Self.inputDeviceIDs().contains(where: Self.deviceIsRunning)
    }

    func start() {
        queue.sync { startOnQueue() }
    }

    func stop() {
        if DispatchQueue.getSpecific(key: queueKey) == true {
            stopOnQueue()
        } else {
            queue.sync { stopOnQueue() }
        }
    }

    private func startOnQueue() {
        guard !isStarted else { return }
        isStarted = true
        lastReportedState = isMicrophoneActive

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.rebuildDeviceListeners()
            self.scheduleEvaluation()
        }
        devicesListener = listener
        let status = AudioObjectAddPropertyListenerBlock(
            systemObject,
            &devicesAddress,
            queue,
            listener
        )
        if status != noErr {
            NSLog("MechaKeys could not observe microphone device changes: %d", status)
        }
        rebuildDeviceListeners()
    }

    private func stopOnQueue() {
        guard isStarted else { return }
        pendingEvaluation?.cancel()
        pendingEvaluation = nil

        if let devicesListener {
            AudioObjectRemovePropertyListenerBlock(
                systemObject,
                &devicesAddress,
                queue,
                devicesListener
            )
        }
        self.devicesListener = nil
        removeDeviceListeners()
        isStarted = false
    }

    private func rebuildDeviceListeners() {
        guard isStarted else { return }
        removeDeviceListeners()
        for deviceID in Self.inputDeviceIDs() {
            var address = Self.runningAddress
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                self?.scheduleEvaluation()
            }
            let status = AudioObjectAddPropertyListenerBlock(deviceID, &address, queue, listener)
            if status == noErr {
                deviceListeners[deviceID] = listener
            }
        }
    }

    private func removeDeviceListeners() {
        for (deviceID, listener) in deviceListeners {
            var address = Self.runningAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, queue, listener)
        }
        deviceListeners.removeAll()
    }

    private func scheduleEvaluation() {
        guard isStarted else { return }
        pendingEvaluation?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.publishState()
        }
        pendingEvaluation = workItem
        queue.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func publishState() {
        guard isStarted else { return }
        let current = isMicrophoneActive
        guard lastReportedState != current else { return }
        lastReportedState = current
        stateHandler(current)
    }

    private static var runningAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func inputDeviceIDs() -> [AudioDeviceID] {
        allAudioDeviceIDs().filter { deviceID in
            deviceIsAlive(deviceID) && deviceHasInputStreams(deviceID)
        }
    }

    private static func allAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: count)
        let status = devices.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                bytes.baseAddress!
            )
        }
        return status == noErr ? devices : []
    }

    private static func deviceHasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr
            && dataSize >= MemoryLayout<AudioStreamID>.size
    }

    private static func deviceIsAlive(_ deviceID: AudioDeviceID) -> Bool {
        uint32Property(deviceID, selector: kAudioDevicePropertyDeviceIsAlive) == 1
    }

    private static func deviceIsRunning(_ deviceID: AudioDeviceID) -> Bool {
        uint32Property(deviceID, selector: kAudioDevicePropertyDeviceIsRunningSomewhere) == 1
    }

    private static func uint32Property(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        )
        return status == noErr ? value : nil
    }

    deinit {
        stop()
    }
}
