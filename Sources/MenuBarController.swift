import AppKit
import SwiftUI

/// Owns the status item independently of SwiftUI scene insertion/removal.
@MainActor
final class MenuBarController: NSObject {
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private let controlsWindow: NSWindow

    init(appDelegate: AppDelegate) {
        controlsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 640),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        super.init()
        controlsWindow.title = "NotchHarbor Controls — \(appDelegate.version)"
        controlsWindow.isReleasedWhenClosed = false
        controlsWindow.contentViewController = NSHostingController(rootView:
            ScrollView { NotchHarborPanel(appDelegate: appDelegate) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: NotchHarborPanel(appDelegate: appDelegate)
        )
    }

    func setVisible(_ visible: Bool) {
        if visible {
            if let item {
                item.isVisible = true
                return
            }
            let item = NSStatusBar.system.statusItem(withLength: 28)
            let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 2, y: 13))
                path.line(to: NSPoint(x: 6, y: 13))
                path.line(to: NSPoint(x: 6, y: 8))
                path.curve(to: NSPoint(x: 8, y: 6), controlPoint1: NSPoint(x: 6, y: 6), controlPoint2: NSPoint(x: 7, y: 6))
                path.line(to: NSPoint(x: 12, y: 6))
                path.curve(to: NSPoint(x: 14, y: 8), controlPoint1: NSPoint(x: 13, y: 6), controlPoint2: NSPoint(x: 14, y: 6))
                path.line(to: NSPoint(x: 14, y: 13))
                path.line(to: NSPoint(x: 18, y: 13))
                path.lineWidth = 1.5
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                NSColor.black.setStroke()
                path.stroke()
                NSBezierPath(roundedRect: NSRect(x: 7, y: 2, width: 6, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()
                return true
            }
            image.isTemplate = true
            item.button?.image = image
            item.button?.setAccessibilityLabel("NotchHarbor controls")
            item.button?.toolTip = "NotchHarbor"
            item.button?.target = self
            item.button?.action = #selector(togglePopover)
            self.item = item
            item.isVisible = true
        } else {
            popover.close()
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
        }
    }

    func showControls() {
        // Finder reopen must work even when macOS hides a crowded status item.
        popover.close()
        if let screen = NSScreen.main {
            controlsWindow.setContentSize(NSSize(width: 380, height: min(640, screen.visibleFrame.height - 80)))
        }
        controlsWindow.center()
        NSApp.activate(ignoringOtherApps: true)
        controlsWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.close()
        } else if let button = item?.button, button.window?.isVisible == true {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            showControls()
        }
    }
}
