import AppKit

/// Coalesces wake/unlock events and performs one settling check, never polling.
@MainActor
final class WorkspaceLifecycleMonitor {
    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []
    private var wakeTask: DispatchWorkItem?
    private var settlingTask: DispatchWorkItem?
    private let onSleep: () -> Void
    private let onWake: () -> Void
    private var generation = 0

    init(center: NotificationCenter = NSWorkspace.shared.notificationCenter,
         onSleep: @escaping () -> Void, onWake: @escaping () -> Void) {
        self.center = center
        self.onSleep = onSleep
        self.onWake = onWake
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sleep() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleWake() }
            })
        }
    }

    private func cancelPending() {
        generation += 1
        wakeTask?.cancel()
        settlingTask?.cancel()
        wakeTask = nil
        settlingTask = nil
    }

    private func sleep() {
        cancelPending()
        onSleep()
    }

    private func scheduleWake() {
        cancelPending()
        let ticket = generation
        let wake = DispatchWorkItem { [weak self] in
            guard let self, self.generation == ticket else { return }
            self.onWake()
        }
        let settle = DispatchWorkItem { [weak self] in
            guard let self, self.generation == ticket else { return }
            self.onWake()
        }
        wakeTask = wake
        settlingTask = settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: wake)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: settle)
    }

    func stop() {
        cancelPending()
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }
}
