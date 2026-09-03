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
            return status == .enabled || status == .requiresApproval
        }
        return FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func hardenExistingRegistration() {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
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
            return
        }

        if enabled {
            try install()
        } else {
            try remove()
        }
    }

    private static func install() throws {
        guard let executableURL = Bundle.main.executableURL else {
            throw LaunchAtLoginError.missingExecutable
        }

        try FileManager.default.createDirectory(
            at: launchAgentsDirectory,
            withIntermediateDirectories: true
        )

        let propertyList: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive"
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
        guard isEnabled else { return }
        try FileManager.default.removeItem(at: plistURL)
    }

    private static var isInstalledInApplications: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix("/System/Applications/")
    }
}

enum LaunchAtLoginError: LocalizedError {
    case missingExecutable

    var errorDescription: String? {
        "MechaKeys could not find its application executable."
    }
}
