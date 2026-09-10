import Foundation

final class FakeEngine: InputAudioEngine {
    var volume: Float = 0
    var profile: KeyboardSoundProfile = .standard
    var pitchVariationEnabled = true
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var blockStart = false
    var failStart = false
    private let lock = NSLock()
    private var played: [UInt16] = []
    private var actions: [KeyPlaybackAction] = []
    private var intensities: [Float] = []
    private var mice = 0
    private var sleeps = 0
    func start() throws {
        entered.signal()
        if blockStart { release.wait() }
        if failStart { throw NSError(domain: "test", code: 1) }
    }
    func playKeyboard(keyCode: UInt16, action: KeyPlaybackAction, intensity: Float) {
        lock.lock()
        played.append(keyCode)
        actions.append(action)
        intensities.append(intensity)
        lock.unlock()
    }
    func playMouse(button: Int64) { lock.lock(); mice += 1; lock.unlock() }
    func loadCustomSoundPack(_ pack: CustomSoundPack?) throws {}
    func suspend() { lock.lock(); sleeps += 1; lock.unlock() }
    func stop() { suspend() }
    var snapshot: ([UInt16], Int, Int) {
        lock.lock(); defer { lock.unlock() }; return (played, mice, sleeps)
    }
    var playbackSnapshot: ([KeyPlaybackAction], [Float]) {
        lock.lock(); defer { lock.unlock() }; return (actions, intensities)
    }
}

@main
struct AudioLifecycleTests {
    static func main() {
        precondition(PlaybackPolicy.shouldEnable(userEnabled: true, bluetoothAudioConnected: false, muteDuringCalls: true, microphoneActive: false))
        precondition(!PlaybackPolicy.shouldEnable(userEnabled: true, bluetoothAudioConnected: true, muteDuringCalls: false, microphoneActive: false))
        precondition(!PlaybackPolicy.shouldEnable(userEnabled: true, bluetoothAudioConnected: false, muteDuringCalls: true, microphoneActive: true))
        precondition(PlaybackPolicy.shouldEnable(userEnabled: true, bluetoothAudioConnected: false, muteDuringCalls: false, microphoneActive: true))

        let engine = FakeEngine()
        engine.blockStart = true
        let controller = InputAudioController(engine: engine, volume: 0.5, profile: .red, idleTimeout: 0.05)
        controller.handle(.keyDown(1))
        precondition(engine.entered.wait(timeout: .now() + 2) == .success)
        controller.handle(.keyDown(2))
        controller.handle(.mouseDown(0))
        controller.handle(.keyDown(3))
        engine.release.signal()
        Thread.sleep(forTimeInterval: 0.03)
        precondition(engine.snapshot.0 == [3], "Only the latest wake key is played")
        precondition(engine.snapshot.1 == 0, "Wake mouse clicks must be discarded")
        Thread.sleep(forTimeInterval: 0.4)
        precondition(engine.snapshot.2 > 0, "Idle audio must suspend")
        controller.stopSynchronously()

        let canceled = FakeEngine()
        canceled.blockStart = true
        let second = InputAudioController(engine: canceled, volume: 0.5, profile: .red, idleTimeout: 30)
        second.handle(.keyDown(9))
        precondition(canceled.entered.wait(timeout: .now() + 2) == .success)
        second.suspend()
        canceled.release.signal()
        second.stopSynchronously()
        precondition(canceled.snapshot.0.isEmpty, "Suspending invalidates in-flight wake sounds")

        let failing = FakeEngine()
        failing.failStart = true
        let third = InputAudioController(engine: failing, volume: 0.5, profile: .red, idleTimeout: 30)
        let failure = DispatchSemaphore(value: 0)
        third.onHealthChange = { error in if error != nil { failure.signal() } }
        third.warm()
        precondition(failure.wait(timeout: .now() + 2) == .success, "Audio failure must reach UI observer")
        third.stopSynchronously()

        let dynamicsEngine = FakeEngine()
        let dynamics = InputAudioController(
            engine: dynamicsEngine,
            volume: 0.5,
            profile: .standard,
            idleTimeout: 30
        )
        dynamics.setReleaseSoundsEnabled(true)
        dynamics.warm()
        precondition(dynamicsEngine.entered.wait(timeout: .now() + 2) == .success)
        Thread.sleep(forTimeInterval: 0.03)
        dynamics.handle(.keyDown(1))
        Thread.sleep(forTimeInterval: 0.02)
        dynamics.handle(.keyDown(2))
        dynamics.handle(.keyUp(2))
        Thread.sleep(forTimeInterval: 0.05)
        let playback = dynamicsEngine.playbackSnapshot
        precondition(playback.0.contains(where: { $0 == .up }), "Enabled release sounds must reach the engine")
        precondition(playback.1.contains(where: { $0 > 1 }), "Fast typing should receive subtle dynamics")
        dynamics.stopSynchronously()
        print("PASS: wake coalescing, stale protection, idle suspend, release sounds, typing dynamics")
    }
}
