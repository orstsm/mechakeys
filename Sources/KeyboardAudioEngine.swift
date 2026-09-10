import AVFoundation
import Foundation

enum KeyboardSoundProfile: String, CaseIterable, Identifiable {
    case standard = "Default"
    case red = "K Pro Red"
    case alpaca = "Alpaca"
    case custom = "Custom"

    var id: String { rawValue }
}

final class KeyboardAudioEngine {
    private let engine = AVAudioEngine()
    private let players: [AVAudioPlayerNode]
    private let pitchUnits: [AVAudioUnitVarispeed]
    private let defaultBuffers: [AVAudioPCMBuffer]
    private let redKeyBuffers: [AVAudioPCMBuffer]
    private let redMouseBuffer: AVAudioPCMBuffer
    private let redSpaceBuffers: [AVAudioPCMBuffer]
    private let alpacaMouseBuffers: [AVAudioPCMBuffer]
    private let alpacaKeyBuffers: [AVAudioPCMBuffer]
    private let alpacaDeleteBuffers: [AVAudioPCMBuffer]
    private let alpacaSpaceBuffers: [AVAudioPCMBuffer]
    private var customBuffers = CustomBuffers()
    private let lock = NSLock()
    private var nextPlayerIndex = 0
    private var nextDefaultBufferIndex = 0
    private var nextRedKeyBufferIndex = 0
    private var nextRedSpaceBufferIndex = 0
    private var nextAlpacaMouseBufferIndex = 0
    private var nextAlpacaKeyBufferIndex = 0
    private var nextAlpacaDeleteBufferIndex = 0
    private var nextAlpacaSpaceBufferIndex = 0

    var volume: Float = 0.72
    var profile: KeyboardSoundProfile = .standard
    var pitchVariationEnabled = true

    init(polyphony: Int = 8) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioEngineError.couldNotCreateAudioFormat
        }

        defaultBuffers = try (1...4).map {
            try Self.loadRecordedBuffer(named: "DefaultClick\($0)", format: format)
        }

        redKeyBuffers = try (1...10).map {
            try Self.loadRecordedBuffer(named: "KProRedKey\($0)", format: format)
        }
        redMouseBuffer = try Self.loadRecordedBuffer(named: "KProRedMouse", format: format)
        redSpaceBuffers = try (1...4).map {
            try Self.loadRecordedBuffer(named: "KProRedSpace\($0)", format: format)
        }

        alpacaMouseBuffers = try (1...3).map {
            try Self.loadRecordedBuffer(named: "AlpacaMouse\($0)", format: format)
        }
        alpacaKeyBuffers = try (1...5).map {
            try Self.loadRecordedBuffer(named: "AlpacaKey\($0)", format: format)
        }
        alpacaDeleteBuffers = try (1...5).map {
            try Self.loadRecordedBuffer(named: "AlpacaDelete\($0)", format: format)
        }
        alpacaSpaceBuffers = try (1...5).map {
            try Self.loadRecordedBuffer(named: "AlpacaSpace\($0)", format: format)
        }

        players = (0..<polyphony).map { _ in AVAudioPlayerNode() }
        pitchUnits = (0..<polyphony).map { _ in AVAudioUnitVarispeed() }
        for (player, pitchUnit) in zip(players, pitchUnits) {
            engine.attach(player)
            engine.attach(pitchUnit)
            engine.connect(player, to: pitchUnit, format: format)
            engine.connect(pitchUnit, to: engine.mainMixerNode, format: format)
        }

        engine.prepare()
    }

    func playKeyboard(keyCode: UInt16, action: KeyPlaybackAction, intensity: Float) {
        if action == .up {
            playRelease(keyCode: keyCode, intensity: intensity)
            return
        }
        switch profile {
        case .standard:
            playDefault(pan: pan(for: keyCode), intensity: intensity)
        case .red:
            if keyCode == 49 {
                playRedSpace(pan: pan(for: keyCode), intensity: intensity)
            } else {
                playRedKey(pan: pan(for: keyCode), intensity: intensity)
            }
        case .alpaca:
            if keyCode == 49 {
                playAlpacaSpace(pan: pan(for: keyCode), intensity: intensity)
            } else if keyCode == 51 || keyCode == 117 {
                playAlpacaDelete(pan: pan(for: keyCode), intensity: intensity)
            } else {
                playAlpacaKey(pan: pan(for: keyCode), intensity: intensity)
            }
        case .custom:
            playCustom(keyCode: keyCode, action: .down, intensity: intensity)
        }
    }

    func playMouse(button: Int64) {
        let mousePan: Float = button == 1 ? 0.10 : -0.10
        switch profile {
        case .standard:
            playDefault(pan: mousePan, intensity: 1)
        case .red:
            play(buffer: redMouseBuffer, pan: mousePan, intensity: 1)
        case .alpaca:
            playAlpacaMouse(pan: mousePan, intensity: 1)
        case .custom:
            let buffers = customBuffers.mouseDown.isEmpty ? customBuffers.keyDown : customBuffers.mouseDown
            playNext(from: buffers, pan: mousePan, intensity: 1, counter: &customBuffers.nextMouseDown)
        }
    }

    func loadCustomSoundPack(_ pack: CustomSoundPack?) throws {
        guard let pack else {
            customBuffers = CustomBuffers()
            return
        }
        var loaded = CustomBuffers()
        let files = try FileManager.default.contentsOfDirectory(
            at: pack.folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { ["wav", "aiff", "aif", "caf", "mp3"].contains($0.pathExtension.lowercased()) }
        guard let format = players.first?.outputFormat(forBus: 0) else {
            throw AudioEngineError.couldNotCreateAudioFormat
        }
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let buffer = try Self.loadRecordedBuffer(from: file, format: format)
            let category = CustomSoundName.category(for: file.deletingPathExtension().lastPathComponent)
            loaded.append(buffer, action: category.action, kind: category.kind)
        }
        guard !loaded.keyDown.isEmpty else { throw CustomSoundPackError.missingKeySound }
        customBuffers = loaded
    }

    func start() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
        // Keep player nodes rendering silence so warm events can be scheduled
        // without paying a node-start delay on each key press.
        for player in players {
            player.play()
        }
    }

    private func playDefault(pan: Float, intensity: Float) {
        lock.lock()
        let index = nextDefaultBufferIndex
        nextDefaultBufferIndex = (nextDefaultBufferIndex + 1) % defaultBuffers.count
        lock.unlock()

        play(buffer: defaultBuffers[index], pan: pan, intensity: intensity)
    }

    private func playRedKey(pan: Float, intensity: Float) {
        lock.lock()
        let index = nextRedKeyBufferIndex
        nextRedKeyBufferIndex = (nextRedKeyBufferIndex + 1) % redKeyBuffers.count
        lock.unlock()

        play(buffer: redKeyBuffers[index], pan: pan, intensity: intensity)
    }

    private func playRedSpace(pan: Float, intensity: Float) {
        lock.lock()
        let index = nextRedSpaceBufferIndex
        nextRedSpaceBufferIndex = (nextRedSpaceBufferIndex + 1) % redSpaceBuffers.count
        lock.unlock()

        play(buffer: redSpaceBuffers[index], pan: pan, intensity: intensity)
    }

    private func playAlpacaMouse(pan: Float, intensity: Float) {
        lock.lock()
        let index = nextAlpacaMouseBufferIndex
        nextAlpacaMouseBufferIndex = (nextAlpacaMouseBufferIndex + 1) % alpacaMouseBuffers.count
        lock.unlock()

        play(buffer: alpacaMouseBuffers[index], pan: pan, intensity: intensity)
    }

    private func playAlpacaKey(pan: Float, intensity: Float) {
        lock.lock()
        let index = nextAlpacaKeyBufferIndex
        nextAlpacaKeyBufferIndex = (nextAlpacaKeyBufferIndex + 1) % alpacaKeyBuffers.count
        lock.unlock()

        play(buffer: alpacaKeyBuffers[index], pan: pan, intensity: intensity)
    }

    private func playAlpacaDelete(pan: Float, intensity: Float) {
        lock.lock()
        let index = nextAlpacaDeleteBufferIndex
        nextAlpacaDeleteBufferIndex = (nextAlpacaDeleteBufferIndex + 1) % alpacaDeleteBuffers.count
        lock.unlock()

        play(buffer: alpacaDeleteBuffers[index], pan: pan, intensity: intensity)
    }

    private func playAlpacaSpace(pan: Float, intensity: Float) {
        lock.lock()
        let index = nextAlpacaSpaceBufferIndex
        nextAlpacaSpaceBufferIndex = (nextAlpacaSpaceBufferIndex + 1) % alpacaSpaceBuffers.count
        lock.unlock()

        play(buffer: alpacaSpaceBuffers[index], pan: pan, intensity: intensity)
    }

    private func playRelease(keyCode: UInt16, intensity: Float) {
        guard profile == .custom else { return }
        playCustom(keyCode: keyCode, action: .up, intensity: intensity * 0.62)
    }

    private func playCustom(keyCode: UInt16, action: CustomSoundAction, intensity: Float) {
        let kind = keyKind(for: keyCode)
        var buffers = customBuffers.buffers(action: action, kind: kind)
        if buffers.isEmpty { buffers = customBuffers.buffers(action: action, kind: .key) }
        guard !buffers.isEmpty else { return }
        let counter = customBuffers.takeNextCounter(action: action, kind: kind, count: buffers.count)
        play(buffer: buffers[counter], pan: pan(for: keyCode), intensity: intensity)
    }

    private func playNext(
        from buffers: [AVAudioPCMBuffer],
        pan: Float,
        intensity: Float,
        counter: inout Int
    ) {
        guard !buffers.isEmpty else { return }
        let index = counter % buffers.count
        counter = (counter + 1) % buffers.count
        play(buffer: buffers[index], pan: pan, intensity: intensity)
    }

    private func play(buffer: AVAudioPCMBuffer, pan: Float, intensity: Float) {
        lock.lock()
        let index = nextPlayerIndex
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        lock.unlock()

        let player = players[index]
        let pitchUnit = pitchUnits[index]
        player.pan = pan
        player.volume = min(max(volume * intensity, 0), 1)
        pitchUnit.rate = pitchVariationEnabled ? Float.random(in: 0.985...1.015) : 1
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    func suspend() {
        for player in players {
            player.stop()
        }
        engine.stop()
        engine.reset()
    }

    func stop() { suspend() }

    private static func loadRecordedBuffer(
        named name: String,
        format: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "wav",
            subdirectory: "Sounds"
        ) else {
            throw AudioEngineError.missingSoundResource(name)
        }

        return try loadRecordedBuffer(from: url, format: format)
    }

    private static func loadRecordedBuffer(
        from url: URL,
        format: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        let name = url.deletingPathExtension().lastPathComponent
        let file = try AVAudioFile(forReading: url)
        guard let source = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw AudioEngineError.couldNotAllocateBuffer
        }
        try file.read(into: source)

        if file.processingFormat == format {
            return source
        }

        guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else {
            throw AudioEngineError.incompatibleSoundResource(name)
        }
        let ratio = format.sampleRate / file.processingFormat.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(source.frameLength) * ratio)) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw AudioEngineError.couldNotAllocateBuffer
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return source
        }
        guard status != .error else {
            throw conversionError ?? AudioEngineError.incompatibleSoundResource(name)
        }
        return converted
    }

    private func pan(for keyCode: UInt16) -> Float {
        let leftKeys: Set<UInt16> = [0, 1, 6, 7, 12, 13, 14, 15, 16, 17, 18, 19, 20, 50, 53, 56, 57, 58, 59]
        let rightKeys: Set<UInt16> = [29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 40, 41, 42, 43, 44, 46, 47, 51, 60, 61, 62]

        if leftKeys.contains(keyCode) { return -0.28 }
        if rightKeys.contains(keyCode) { return 0.28 }
        return 0
    }

    private func keyKind(for keyCode: UInt16) -> CustomSoundKind {
        if keyCode == 49 { return .space }
        if keyCode == 51 || keyCode == 117 { return .delete }
        if keyCode == 36 || keyCode == 76 { return .enter }
        return .key
    }
}

enum KeyPlaybackAction: Equatable {
    case down
    case up
}

private struct CustomBuffers {
    var keyDown: [AVAudioPCMBuffer] = []
    var spaceDown: [AVAudioPCMBuffer] = []
    var deleteDown: [AVAudioPCMBuffer] = []
    var enterDown: [AVAudioPCMBuffer] = []
    var mouseDown: [AVAudioPCMBuffer] = []
    var keyUp: [AVAudioPCMBuffer] = []
    var spaceUp: [AVAudioPCMBuffer] = []
    var deleteUp: [AVAudioPCMBuffer] = []
    var enterUp: [AVAudioPCMBuffer] = []
    var nextKeyDown = 0
    var nextSpaceDown = 0
    var nextDeleteDown = 0
    var nextEnterDown = 0
    var nextMouseDown = 0
    var nextKeyUp = 0
    var nextSpaceUp = 0
    var nextDeleteUp = 0
    var nextEnterUp = 0

    mutating func append(_ buffer: AVAudioPCMBuffer, action: CustomSoundAction, kind: CustomSoundKind) {
        switch (action, kind) {
        case (.down, .key): keyDown.append(buffer)
        case (.down, .space): spaceDown.append(buffer)
        case (.down, .delete): deleteDown.append(buffer)
        case (.down, .enter): enterDown.append(buffer)
        case (.down, .mouse): mouseDown.append(buffer)
        case (.up, .key), (.up, .mouse): keyUp.append(buffer)
        case (.up, .space): spaceUp.append(buffer)
        case (.up, .delete): deleteUp.append(buffer)
        case (.up, .enter): enterUp.append(buffer)
        }
    }

    func buffers(action: CustomSoundAction, kind: CustomSoundKind) -> [AVAudioPCMBuffer] {
        switch (action, kind) {
        case (.down, .key): return keyDown
        case (.down, .space): return spaceDown
        case (.down, .delete): return deleteDown
        case (.down, .enter): return enterDown
        case (.down, .mouse): return mouseDown
        case (.up, .key), (.up, .mouse): return keyUp
        case (.up, .space): return spaceUp
        case (.up, .delete): return deleteUp
        case (.up, .enter): return enterUp
        }
    }

    mutating func takeNextCounter(
        action: CustomSoundAction,
        kind: CustomSoundKind,
        count: Int
    ) -> Int {
        let index: Int
        switch (action, kind) {
        case (.down, .key): index = nextKeyDown; nextKeyDown += 1
        case (.down, .space): index = nextSpaceDown; nextSpaceDown += 1
        case (.down, .delete): index = nextDeleteDown; nextDeleteDown += 1
        case (.down, .enter): index = nextEnterDown; nextEnterDown += 1
        case (.down, .mouse): index = nextMouseDown; nextMouseDown += 1
        case (.up, .key), (.up, .mouse): index = nextKeyUp; nextKeyUp += 1
        case (.up, .space): index = nextSpaceUp; nextSpaceUp += 1
        case (.up, .delete): index = nextDeleteUp; nextDeleteUp += 1
        case (.up, .enter): index = nextEnterUp; nextEnterUp += 1
        }
        return index % count
    }
}

enum AudioEngineError: LocalizedError {
    case couldNotCreateAudioFormat
    case couldNotAllocateBuffer
    case missingSoundResource(String)
    case incompatibleSoundResource(String)

    var errorDescription: String? {
        switch self {
        case .couldNotCreateAudioFormat:
            return "The keyboard audio format could not be created."
        case .couldNotAllocateBuffer:
            return "The keyboard sound could not be loaded into memory."
        case .missingSoundResource(let name):
            return "The bundled sound \(name).wav is missing."
        case .incompatibleSoundResource(let name):
            return "The bundled sound \(name).wav has an unsupported format."
        }
    }
}
