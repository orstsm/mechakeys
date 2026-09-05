import Foundation

final class FakeEngine: InputAudioEngine {
    var volume: Float = 0
    var profile: KeyboardSoundProfile = .standard
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var blockStart = false
    var failStart = false
    private let lock = NSLock()
    private var played: [UInt16] = []
    private var mice = 0
    private var sleeps = 0
    func start() throws {
        entered.signal()
        if blockStart { release.wait() }
        if failStart { throw NSError(domain: "test", code: 1) }
    }
    func playKeyboard(keyCode: UInt16) { lock.lock(); played.append(keyCode); lock.unlock() }
    func playMouse(button: Int64) { lock.lock(); mice += 1; lock.unlock() }
    func suspend() { lock.lock(); sleeps += 1; lock.unlock() }
    func stop() { suspend() }
    var snapshot: ([UInt16], Int, Int) {
        lock.lock(); defer { lock.unlock() }; return (played, mice, sleeps)
    }
}

@main
struct AudioLifecycleTests {
    static func main() {
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
        print("PASS: wake coalescing, discarded mouse clicks, idle suspend, canceled wake, error reporting")
    }
}
