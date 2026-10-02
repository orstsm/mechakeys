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
        throw NSError(domain: "Installer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Quit NotchHarbor (or MechaKeys) before installing. The running app has not been changed."])
    }
    let fm = FileManager.default
    let source = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let destination = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
    guard source != destination, destination.pathExtension == "app" else {
        throw NSError(domain: "Installer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Source and installed application must be separate app bundles"])
    }
    try verify(source)
    let parent = destination.deletingLastPathComponent()
    // Only migrate the exact legacy sibling, never arbitrary app copies or data.
    let legacy = parent.appendingPathComponent("MechaKeys.app")
    let migrateLegacy = destination.lastPathComponent == "NotchHarbor.app" && fm.fileExists(atPath: legacy.path)
    if migrateLegacy { try verify(legacy) }
    let replacing = fm.fileExists(atPath: destination.path)
    if replacing { try verify(destination) }
    try fm.createDirectory(at: parent, withIntermediateDirectories: true)
    let stage = parent.appendingPathComponent(".notchharbor-install-\(UUID().uuidString).noindex")
    try fm.createDirectory(at: stage, withIntermediateDirectories: false)
    let replacement = stage.appendingPathComponent("NotchHarbor.app")
    try fm.copyItem(at: source, to: replacement)
    try verify(replacement)
    if replacing {
        // Atomic exchange on the same volume: interruption never leaves no app.
        let result = renameatx_np(AT_FDCWD, replacement.path, AT_FDCWD, destination.path, UInt32(RENAME_SWAP))
        guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    } else {
        try fm.moveItem(at: replacement, to: destination)
    }
    do {
        try verify(destination)
        if migrateLegacy {
            let backup = stage.appendingPathComponent("MechaKeys.bundle-backup")
            try fm.moveItem(at: legacy, to: backup)
            print("Legacy application retained at \(backup.path)")
        }
    } catch {
        if replacing {
            let rollback = renameatx_np(AT_FDCWD, replacement.path, AT_FDCWD, destination.path, UInt32(RENAME_SWAP))
            if rollback != 0 { print("Rollback failed; preserved recovery files at \(stage.path)") }
        } else {
            try? fm.moveItem(at: destination, to: stage.appendingPathComponent("failed.bundle-backup"))
        }
        throw error
    }
    if replacing {
        let backup = stage.appendingPathComponent("previous.bundle-backup")
        try fm.moveItem(at: replacement, to: backup)
        print("Previous version retained at \(backup.path)")
    } else if !migrateLegacy {
        try fm.removeItem(at: stage)
    }
    print("Installed \(destination.path). Open it from Finder. A local rebuild may need Input Monitoring reauthorization.")
} catch {
    fputs("Installation stopped: \(error.localizedDescription)\n", stderr)
    exit(1)
}
