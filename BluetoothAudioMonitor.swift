import CoreAudio
import Foundation

final class BluetoothAudioMonitor {
    typealias StateHandler = (Bool) -> Void

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let queue = DispatchQueue(label: "com.mechakeys.bluetooth-audio", qos: .utility)
    private let queueKey = DispatchSpecificKey<Bool>()
    private let stateHandler: StateHandler
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var pendingEvaluation: DispatchWorkItem?
    private var pendingFollowUpEvaluation: DispatchWorkItem?
    private var lastReportedBluetoothState: Bool?
    private var isStarted = false

    private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var defaultSystemOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    init(stateHandler: @escaping StateHandler) {
        self.stateHandler = stateHandler
        queue.setSpecific(key: queueKey, value: true)
    }

    var hasConnectedBluetoothAudioOutput: Bool {
        Self.connectedBluetoothAudioOutputDeviceIDs().isEmpty == false
    }

    func start() {
        queue.sync { startOnQueue() }
    }

    private func startOnQueue() {
        guard !isStarted else { return }
        lastReportedBluetoothState = hasConnectedBluetoothAudioOutput

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.scheduleEvaluation()
        }
        listenerBlock = block

        let deviceStatus = AudioObjectAddPropertyListenerBlock(
            systemObject,
            &devicesAddress,
            queue,
            block
        )
        let outputStatus = AudioObjectAddPropertyListenerBlock(
            systemObject,
            &defaultOutputAddress,
            queue,
            block
        )
        let systemOutputStatus = AudioObjectAddPropertyListenerBlock(
            systemObject,
            &defaultSystemOutputAddress,
            queue,
            block
        )

        if deviceStatus != noErr || outputStatus != noErr || systemOutputStatus != noErr {
            NSLog(
                "MechaKeys could not install every audio-route listener: %d, %d, %d",
                deviceStatus,
                outputStatus,
                systemOutputStatus
            )
        }
        isStarted = true
    }

    func stop() {
        if DispatchQueue.getSpecific(key: queueKey) == true {
            stopOnQueue()
        } else {
            queue.sync { stopOnQueue() }
        }
    }

    private func stopOnQueue() {
        guard isStarted, let listenerBlock else { return }
        pendingEvaluation?.cancel()
        pendingEvaluation = nil
        pendingFollowUpEvaluation?.cancel()
        pendingFollowUpEvaluation = nil

        AudioObjectRemovePropertyListenerBlock(
            systemObject,
            &devicesAddress,
            queue,
            listenerBlock
        )
        AudioObjectRemovePropertyListenerBlock(
            systemObject,
            &defaultOutputAddress,
            queue,
            listenerBlock
        )
        AudioObjectRemovePropertyListenerBlock(
            systemObject,
            &defaultSystemOutputAddress,
            queue,
            listenerBlock
        )
        self.listenerBlock = nil
        isStarted = false
    }

    private func scheduleEvaluation() {
        guard isStarted else { return }
        pendingEvaluation?.cancel()
        pendingFollowUpEvaluation?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.publishState(alwaysNotify: true)
        }
        pendingEvaluation = workItem
        queue.asyncAfter(deadline: .now() + 0.75, execute: workItem)

        // Bluetooth audio devices can briefly appear before their output stream
        // and alive properties finish initializing. Recheck once without causing
        // a second route rebuild unless the Bluetooth state actually changed.
        let followUp = DispatchWorkItem { [weak self] in
            self?.publishState(alwaysNotify: false)
        }
        pendingFollowUpEvaluation = followUp
        queue.asyncAfter(deadline: .now() + 2.5, execute: followUp)
    }

    private func publishState(alwaysNotify: Bool) {
        guard isStarted else { return }
        let currentState = hasConnectedBluetoothAudioOutput
        let changed = lastReportedBluetoothState != currentState
        lastReportedBluetoothState = currentState
        if alwaysNotify || changed {
            stateHandler(currentState)
        }
    }

    private static func connectedBluetoothAudioOutputDeviceIDs() -> Set<AudioDeviceID> {
        Set(allAudioDeviceIDs().filter { deviceID in
            guard deviceIsAlive(deviceID), deviceHasOutputStreams(deviceID) else { return false }
            guard let transport = uint32Property(
                objectID: deviceID,
                selector: kAudioDevicePropertyTransportType,
                scope: kAudioObjectPropertyScopeGlobal
            ) else {
                return false
            }
            return transport == kAudioDeviceTransportTypeBluetooth
                || transport == kAudioDeviceTransportTypeBluetoothLE
        })
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
        ) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        let status = deviceIDs.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                bytes.baseAddress!
            )
        }
        return status == noErr ? deviceIDs : []
    }

    private static func deviceIsAlive(_ deviceID: AudioDeviceID) -> Bool {
        uint32Property(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceIsAlive,
            scope: kAudioObjectPropertyScopeGlobal
        ) == 1
    }

    private static func deviceHasOutputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &dataSize
        )
        return status == noErr && dataSize >= MemoryLayout<AudioStreamID>.size
    }

    private static func uint32Property(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            objectID,
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
