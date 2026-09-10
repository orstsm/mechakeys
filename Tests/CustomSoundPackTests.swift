import AVFoundation
import Foundation

@main
struct CustomSoundPackTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mechakeys-pack-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("My Switch", isDirectory: true)
        let libraryRoot = root.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try writeTone(to: source.appendingPathComponent("key1.wav"))
        try writeTone(to: source.appendingPathComponent("release_key1.wav"))

        let library = try CustomSoundPackLibrary(rootURL: libraryRoot)
        let imported = try library.importPack(from: source)
        precondition(imported.name == "My Switch")
        precondition(imported.hasReleaseSounds)
        precondition(library.availablePacks().map(\.id) == [imported.id])
        precondition(CustomSoundName.category(for: "press_space_1").kind == .space)
        precondition(CustomSoundName.category(for: "release_back_1").action == .up)
        print("PASS: validated atomic custom sound-pack import and filename mapping")
    }

    private static func writeTone(to url: URL) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)!
        buffer.frameLength = 480
        if let channel = buffer.floatChannelData?[0] {
            for frame in 0..<480 { channel[frame] = frame == 0 ? 0.05 : 0 }
        }
        try file.write(from: buffer)
    }
}
