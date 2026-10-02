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
        controlsWindow.title = "MechaKeys Controls — \(appDelegate.version)"
        controlsWindow.isReleasedWhenClosed = false
        controlsWindow.contentViewController = NSHostingController(rootView:
            ScrollView { MechaKeysPanel(appDelegate: appDelegate) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MechaKeysPanel(appDelegate: appDelegate)
        )
    }

    func setVisible(_ visible: Bool) {
        if visible {
            if let item {
                item.isVisible = true
                return
            }
            let item = NSStatusBar.system.statusItem(withLength: 28)
            let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MechaKeys")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            item.button?.image = image
            if image == nil { item.button?.title = "MK" }
            item.button?.setAccessibilityLabel("MechaKeys controls")
            item.button?.toolTip = "MechaKeys"
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
