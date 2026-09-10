import CoreGraphics
import Foundation

enum GlobalInputEvent {
    case keyDown(UInt16)
    case keyUp(UInt16)
    case mouseDown(Int64)
}

final class GlobalKeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onInput: (GlobalInputEvent) -> Void
    var suppressKeyRepeat = true
    private var repeatFilter = KeyRepeatFilter()

    init(onInput: @escaping (GlobalInputEvent) -> Void) {
        self.onInput = onInput
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let monitoredTypes: [CGEventType] = [
            .keyDown,
            .keyUp,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
        ]
        let eventMask = monitoredTypes.reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: keyboardEventCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        repeatFilter.reset()
    }

    func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            repeatFilter.reset()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !repeatFilter.shouldAcceptKeyDown(
                keyCode,
                isAutoRepeat: isAutoRepeat,
                suppressionEnabled: suppressKeyRepeat
            ) {
                return
            }
            onInput(.keyDown(keyCode))
        case .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let wasPressed = repeatFilter.handleKeyUp(keyCode)
            if wasPressed {
                onInput(.keyUp(keyCode))
            }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            onInput(.mouseDown(button))
        default:
            break
        }
    }

    deinit {
        stop()
    }
}

struct KeyRepeatFilter {
    private var pressedKeys = Set<UInt16>()

    mutating func shouldAcceptKeyDown(
        _ keyCode: UInt16,
        isAutoRepeat: Bool,
        suppressionEnabled: Bool
    ) -> Bool {
        if suppressionEnabled && (isAutoRepeat || pressedKeys.contains(keyCode)) {
            return false
        }
        pressedKeys.insert(keyCode)
        return true
    }

    mutating func handleKeyUp(_ keyCode: UInt16) -> Bool {
        pressedKeys.remove(keyCode) != nil
    }

    mutating func reset() {
        pressedKeys.removeAll()
    }
}

private func keyboardEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<GlobalKeyboardMonitor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    monitor.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
