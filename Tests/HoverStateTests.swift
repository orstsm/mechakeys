import Foundation

@main
struct HoverStateTests {
    @MainActor
    static func main() {
        let model = ShelfModel()
        model.reportPointerState(inside: true, now: 1)
        precondition(model.isExpanded, "First pointer sample must open immediately")
        model.reportPointerState(inside: false, now: 1.04)
        model.reportPointerState(inside: true, now: 2)
        precondition(model.isExpanded, "Returning during close delay must keep it open")
        model.reportPointerState(inside: true, now: 2.09)
        precondition(model.isExpanded, "Remaining inside keeps the shelf open")

        model.reportPointerState(inside: false, now: 3)
        model.reportPointerState(inside: true, now: 3.1)
        model.reportPointerState(inside: true, now: 3.4)
        precondition(model.isExpanded, "Returning must cancel closing")
        model.reportPointerState(inside: false, now: 4)
        model.reportPointerState(inside: false, now: 4.29)
        precondition(!model.isExpanded, "Leaving must close the shelf")

        for cycle in 0..<100 {
            let start = Double(cycle) + 10
            model.reportPointerState(inside: true, now: start)
            precondition(model.isExpanded, "Every fresh entry opens on its first sample")
            model.reportPointerState(inside: true, now: start + 0.1)
            precondition(model.isExpanded, "Repeated hover must always reopen")
            model.reportPointerState(inside: false, now: start + 0.2)
            model.reportPointerState(inside: false, now: start + 0.5)
            precondition(!model.isExpanded, "Repeated leave must always close")
        }

        model.openManually()
        model.reportPointerState(inside: false, now: 200)
        model.reportPointerState(inside: false, now: 201)
        precondition(model.isExpanded, "Finder opening stays available")
        model.closeExplicitly()
        model.reportPointerState(inside: true, now: 202)
        model.reportPointerState(inside: true, now: 204)
        precondition(!model.isExpanded, "Explicit close waits for pointer exit")
        model.reportPointerState(inside: false, now: 205)
        model.reportPointerState(inside: true, now: 206)
        model.reportPointerState(inside: true, now: 206.1)
        precondition(model.isExpanded, "A fresh hover rearms after explicit close")
        model.setVisible(false)
        model.reportPointerState(inside: true, now: 207)
        model.reportPointerState(inside: true, now: 208)
        precondition(!model.isExpanded, "Hidden shelf cannot reopen")
        model.stop()
        print("PASS: immediate opening, canceled close, 100 cycles, manual opening, explicit close, visibility")
    }
}
