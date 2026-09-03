import AVFoundation
import Foundation

enum KeyboardSoundProfile: String, CaseIterable, Identifiable {
    case standard = "Default"
    case red = "K Pro Red"
    case alpaca = "Alpaca"

    var id: String { rawValue }
}

final class KeyboardAudioEngine {
    private let engine = AVAudioEngine()
    private let players: [AVAudioPlayerNode]
    private let defaultBuffers: [AVAudioPCMBuffer]
    private let redKeyBuffers: [AVAudioPCMBuffer]
    private let redMouseBuffer: AVAudioPCMBuffer
    private let redSpaceBuffers: [AVAudioPCMBuffer]
    private let alpacaMouseBuffers: [AVAudioPCMBuffer]
    private let alpacaKeyBuffers: [AVAudioPCMBuffer]
    private let alpacaDeleteBuffers: [AVAudioPCMBuffer]
    private let alpacaSpaceBuffers: [AVAudioPCMBuffer]
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
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        engine.prepare()
    }

    func playKeyboard(keyCode: UInt16) {
        switch profile {
        case .standard:
            playDefault(pan: pan(for: keyCode))
        case .red:
            if keyCode == 49 {
                playRedSpace(pan: pan(for: keyCode))
            } else {
                playRedKey(pan: pan(for: keyCode))
            }
        case .alpaca:
            if keyCode == 49 {
                playAlpacaSpace(pan: pan(for: keyCode))
            } else if keyCode == 51 || keyCode == 117 {
                playAlpacaDelete(pan: pan(for: keyCode))
            } else {
                playAlpacaKey(pan: pan(for: keyCode))
            }
        }
    }

    func playMouse(button: Int64) {
        let mousePan: Float = button == 1 ? 0.10 : -0.10
        switch profile {
        case .standard:
            playDefault(pan: mousePan)
        case .red:
            play(buffer: redMouseBuffer, pan: mousePan)
        case .alpaca:
            playAlpacaMouse(pan: mousePan)
        }
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

    private func playDefault(pan: Float) {
        lock.lock()
        let index = nextDefaultBufferIndex
        nextDefaultBufferIndex = (nextDefaultBufferIndex + 1) % defaultBuffers.count
        lock.unlock()

        play(buffer: defaultBuffers[index], pan: pan)
    }

    private func playRedKey(pan: Float) {
        lock.lock()
        let index = nextRedKeyBufferIndex
        nextRedKeyBufferIndex = (nextRedKeyBufferIndex + 1) % redKeyBuffers.count
        lock.unlock()

        play(buffer: redKeyBuffers[index], pan: pan)
    }

    private func playRedSpace(pan: Float) {
        lock.lock()
        let index = nextRedSpaceBufferIndex
        nextRedSpaceBufferIndex = (nextRedSpaceBufferIndex + 1) % redSpaceBuffers.count
        lock.unlock()

        play(buffer: redSpaceBuffers[index], pan: pan)
    }

    private func playAlpacaMouse(pan: Float) {
        lock.lock()
        let index = nextAlpacaMouseBufferIndex
        nextAlpacaMouseBufferIndex = (nextAlpacaMouseBufferIndex + 1) % alpacaMouseBuffers.count
        lock.unlock()

        play(buffer: alpacaMouseBuffers[index], pan: pan)
    }

    private func playAlpacaKey(pan: Float) {
        lock.lock()
        let index = nextAlpacaKeyBufferIndex
        nextAlpacaKeyBufferIndex = (nextAlpacaKeyBufferIndex + 1) % alpacaKeyBuffers.count
        lock.unlock()

        play(buffer: alpacaKeyBuffers[index], pan: pan)
    }

    private func playAlpacaDelete(pan: Float) {
        lock.lock()
        let index = nextAlpacaDeleteBufferIndex
        nextAlpacaDeleteBufferIndex = (nextAlpacaDeleteBufferIndex + 1) % alpacaDeleteBuffers.count
        lock.unlock()

        play(buffer: alpacaDeleteBuffers[index], pan: pan)
    }

    private func playAlpacaSpace(pan: Float) {
        lock.lock()
        let index = nextAlpacaSpaceBufferIndex
        nextAlpacaSpaceBufferIndex = (nextAlpacaSpaceBufferIndex + 1) % alpacaSpaceBuffers.count
        lock.unlock()

        play(buffer: alpacaSpaceBuffers[index], pan: pan)
    }

    private func play(buffer: AVAudioPCMBuffer, pan: Float) {
        lock.lock()
        let index = nextPlayerIndex
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        lock.unlock()

        let player = players[index]
        player.pan = pan
        player.volume = volume
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
