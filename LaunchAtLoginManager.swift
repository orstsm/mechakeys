import Foundation
import ServiceManagement
#if canImport(Darwin)
import Darwin
#endif

enum LaunchAtLoginManager {
    private static let label = "com.mechakeys.app"

    private static var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private static var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    static var isEnabled: Bool {
        if isInstalledInApplications {
            let status = SMAppService.mainApp.status
            return status == .enabled
        }
        return FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func hardenExistingRegistration() {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        if isInstalledInApplications {
            // Keep the old registration until the replacement is approved.
            do {
                if SMAppService.mainApp.status == .notRegistered {
                    try SMAppService.mainApp.register()
                }
                if SMAppService.mainApp.status == .enabled { try remove() }
            } catch {
                NSLog("MechaKeys login migration deferred: %@", error.localizedDescription)
            }
            return
        }
        // Keep legacy launch-agent registrations pointed at the copy that is
        // currently running. This also repairs registrations created before
        // the app was moved into the user's Applications folder.
        try? install()
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: plistURL.path
        )
    }

    static func setEnabled(_ enabled: Bool) throws {
        if isInstalledInApplications {
            if enabled, SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register()
            } else if !enabled, SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            if !enabled || SMAppService.mainApp.status == .enabled { try remove() }
            if enabled, SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
            return
        }

        if enabled {
            try install()
        } else {
            try remove()
        }
    }

    private static func install() throws {
        guard Bundle.main.executableURL != nil else {
            throw LaunchAtLoginError.missingExecutable
        }

        let applicationURL = Bundle.main.bundleURL.standardizedFileURL

        try FileManager.default.createDirectory(
            at: launchAgentsDirectory,
            withIntermediateDirectories: true
        )

        let propertyList: [String: Any] = [
            "Label": label,
            // Launch through Launch Services so macOS registers MechaKeys as
            // an application. Starting the Mach-O executable directly breaks
            // reopen behavior and cross-app notifications after login.
            "ProgramArguments": ["/usr/bin/open", "-gj", applicationURL.path],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
            "ThrottleInterval": 60
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: plistURL.path
        )
    }

    private static func remove() throws {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        try FileManager.default.removeItem(at: plistURL)
    }

    private static var isInstalledInApplications: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true).path + "/"
        return path.hasPrefix("/Applications/") || path.hasPrefix(userApplications)
    }
}

enum LaunchAtLoginError: LocalizedError {
    case missingExecutable

    var errorDescription: String? {
        "MechaKeys could not find its application executable."
    }
}
