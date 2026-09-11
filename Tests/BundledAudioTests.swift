import Foundation

@main
struct BundledAudioTests {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Pass the Resources directory")
        }
        let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let count = try KeyboardAudioEngine.validateBundledAudioFiles(resourceURL: resources)
        precondition(count == 83, "Expected all 83 bundled recordings, found \(count)")
        print("PASS: all 83 bundled recordings decode into the 48 kHz playback format")
    }
}
