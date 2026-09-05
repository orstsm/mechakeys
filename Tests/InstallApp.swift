// Installation utility; intentionally separate from the application executable.
import AppKit
import Darwin
import Foundation

func verify(_ app: URL) throws {
    guard Bundle(url: app)?.bundleIdentifier == "com.mechakeys.app" else {
        throw NSError(domain: "Installer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected application identity"])
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    process.arguments = ["--verify", "--deep", "--strict", app.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "Installer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Signature verification failed"])
    }
}

do {
    guard CommandLine.arguments.count == 3 else { fatalError("Expected source and destination") }
    guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.mechakeys.app").isEmpty else {
        throw NSError(domain: "Installer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Quit MechaKeys before installing. The running app has not been changed."])
    }
    let fm = FileManager.default
    let source = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let destination = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
    try verify(source)
    let parent = destination.deletingLastPathComponent()
    try fm.createDirectory(at: parent, withIntermediateDirectories: true)
    let stage = parent.appendingPathComponent(".mechakeys-install-\(UUID().uuidString).noindex")
    try fm.createDirectory(at: stage, withIntermediateDirectories: false)
    let replacement = stage.appendingPathComponent("MechaKeys.app")
    try fm.copyItem(at: source, to: replacement)
    try verify(replacement)
    if fm.fileExists(atPath: destination.path) {
        // Atomic exchange on the same volume: interruption never leaves no app.
        let result = renameatx_np(AT_FDCWD, replacement.path, AT_FDCWD, destination.path, UInt32(RENAME_SWAP))
        guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        do { try verify(destination) } catch {
            let rollback = renameatx_np(AT_FDCWD, replacement.path, AT_FDCWD, destination.path, UInt32(RENAME_SWAP))
            if rollback != 0 { print("Rollback failed; preserved recovery files at \(stage.path)") }
            throw error
        }
        let backup = stage.appendingPathComponent("previous.bundle-backup")
        try fm.moveItem(at: replacement, to: backup)
        print("Previous version retained at \(backup.path)")
    } else {
        try fm.moveItem(at: replacement, to: destination)
        try fm.removeItem(at: stage)
    }
    print("Installed \(destination.path). Open it from Finder. A local rebuild may need Input Monitoring reauthorization.")
} catch {
    fputs("Installation stopped: \(error.localizedDescription)\n", stderr)
    exit(1)
}
