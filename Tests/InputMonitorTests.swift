import Foundation

@main
struct InputMonitorTests {
    static func main() {
        var filter = KeyRepeatFilter()
        precondition(filter.shouldAcceptKeyDown(12, isAutoRepeat: false, suppressionEnabled: true))
        precondition(!filter.shouldAcceptKeyDown(12, isAutoRepeat: false, suppressionEnabled: true))
        precondition(!filter.shouldAcceptKeyDown(12, isAutoRepeat: true, suppressionEnabled: true))
        precondition(filter.handleKeyUp(12))
        precondition(filter.shouldAcceptKeyDown(12, isAutoRepeat: false, suppressionEnabled: true))
        print("PASS: held-key repeat suppression and release tracking")
    }
}
