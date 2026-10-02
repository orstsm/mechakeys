import AppKit

@main
struct WorkspaceLifecycleTests {
    @MainActor
    static func main() {
        let center = NotificationCenter()
        var sleeps = 0
        var wakes = 0
        let monitor = WorkspaceLifecycleMonitor(center: center,
            onSleep: { sleeps += 1 }, onWake: { wakes += 1 })
        func wait(_ duration: TimeInterval) {
            RunLoop.main.run(until: Date().addingTimeInterval(duration))
        }
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        precondition(sleeps == 1)
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        wait(0.3)
        precondition(wakes == 1, "Wake and unlock must coalesce")
        wait(1.5)
        precondition(wakes == 2, "One settling check restores late devices")
        wait(0.3)
        precondition(wakes == 2, "No continuous recovery polling")
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        wait(1.7)
        precondition(wakes == 2, "Returning to sleep cancels pending recovery")
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        monitor.stop()
        wait(1.7)
        precondition(wakes == 2, "Termination cancels pending recovery")
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        precondition(sleeps == 2, "Termination removes all observers")
        print("PASS: sleep/wake, unlock coalescing, bounded settling, sleep/stop cancellation")
    }
}
