import AVFoundation
import Foundation

struct CustomSoundPack: Identifiable, Hashable {
    let id: String
    let name: String
    let folderURL: URL
    let hasReleaseSounds: Bool
}

enum CustomSoundPackError: LocalizedError {
    case notFolder
    case symbolicLink
    case tooManyFiles
    case tooLarge
    case unsupportedFile(String)
    case missingKeySound
    case invalidAudio(String)

    var errorDescription: String? {
        switch self {
        case .notFolder:
            return "Choose a folder containing a custom sound pack."
        case .symbolicLink:
            return "Sound packs cannot contain aliases or symbolic links."
        case .tooManyFiles:
            return "A sound pack can contain at most 64 audio files."
        case .tooLarge:
            return "A sound pack can use at most 25 MB of audio."
        case .unsupportedFile(let name):
            return "Unsupported sound file: \(name). Use WAV, AIFF, CAF, or MP3."
        case .missingKeySound:
            return "The pack needs at least one regular key sound, such as key1.wav or press_standard_1.wav."
        case .invalidAudio(let name):
            return "\(name) is not a readable audio file, or is longer than two seconds."
        }
    }
}

final class CustomSoundPackLibrary {
    private let fileManager: FileManager
    private let rootURL: URL
    private let maximumAudioBytes: Int64 = 25 * 1_024 * 1_024
    private let maximumFileBytes: Int64 = 5 * 1_024 * 1_024
    private let maximumAudioFiles = 64

    init(fileManager: FileManager = .default, rootURL: URL? = nil) throws {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            guard let support = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            self.rootURL = support
                .appendingPathComponent("MechaKeys", isDirectory: true)
                .appendingPathComponent("SoundPacks", isDirectory: true)
        }
        try fileManager.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    func availablePacks() -> [CustomSoundPack] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let folders = (try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        return folders.compactMap { folder in
            guard let values = try? folder.resourceValues(forKeys: keys),
                  values.isDirectory == true,
                  values.isSymbolicLink != true,
                  let inspection = try? inspect(folder: folder) else {
                return nil
            }
            return CustomSoundPack(
                id: folder.lastPathComponent,
                name: displayName(for: folder),
                folderURL: folder,
                hasReleaseSounds: inspection.hasReleaseSounds
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func importPack(from sourceURL: URL) throws -> CustomSoundPack {
        let inspection = try inspect(folder: sourceURL)
        let identifier = UUID().uuidString.lowercased()
        let stagingURL = rootURL.appendingPathComponent(".import-\(identifier)", isDirectory: true)
        let destinationURL = rootURL.appendingPathComponent(identifier, isDirectory: true)

        try? fileManager.removeItem(at: stagingURL)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
        do {
            for sourceFile in inspection.audioFiles {
                try fileManager.copyItem(
                    at: sourceFile,
                    to: stagingURL.appendingPathComponent(sourceFile.lastPathComponent)
                )
            }
            let metadata = PackMetadata(name: displayName(for: sourceURL))
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(
                to: stagingURL.appendingPathComponent("manifest.json"),
                options: .atomic
            )
            _ = try inspect(folder: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }

        return CustomSoundPack(
            id: identifier,
            name: displayName(for: destinationURL),
            folderURL: destinationURL,
            hasReleaseSounds: inspection.hasReleaseSounds
        )
    }

    private struct Inspection {
        let audioFiles: [URL]
        let hasReleaseSounds: Bool
    }

    private struct PackMetadata: Codable {
        let name: String
    }

    private func inspect(folder: URL) throws -> Inspection {
        let folderValues = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard folderValues.isDirectory == true else { throw CustomSoundPackError.notFolder }
        guard folderValues.isSymbolicLink != true else { throw CustomSoundPackError.symbolicLink }

        let files = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var audioFiles: [URL] = []
        var totalBytes: Int64 = 0
        var hasKeySound = false
        var hasReleaseSound = false

        for file in files {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true else { throw CustomSoundPackError.symbolicLink }
            guard values.isRegularFile == true else { continue }

            let lowerName = file.lastPathComponent.lowercased()
            if ["manifest.json", "keebs_meta.json", "config.json", "profile.yaml", "profile.yml",
                "cover.png", "cover.jpg", "cover.jpeg"]
                .contains(lowerName) {
                continue
            }
            let ext = file.pathExtension.lowercased()
            guard ["wav", "aiff", "aif", "caf", "mp3"].contains(ext) else {
                throw CustomSoundPackError.unsupportedFile(file.lastPathComponent)
            }
            guard audioFiles.count < maximumAudioFiles else { throw CustomSoundPackError.tooManyFiles }
            let bytes = Int64(values.fileSize ?? 0)
            guard bytes > 0, bytes <= maximumFileBytes else { throw CustomSoundPackError.tooLarge }
            totalBytes += bytes
            guard totalBytes <= maximumAudioBytes else { throw CustomSoundPackError.tooLarge }

            let category = CustomSoundName.category(for: file.deletingPathExtension().lastPathComponent)
            if category.action == .down && category.kind == .key { hasKeySound = true }
            if category.action == .up { hasReleaseSound = true }

            let audio = try AVAudioFile(forReading: file)
            let duration = Double(audio.length) / audio.processingFormat.sampleRate
            guard duration.isFinite, duration > 0, duration <= 2 else {
                throw CustomSoundPackError.invalidAudio(file.lastPathComponent)
            }
            audioFiles.append(file)
        }

        guard hasKeySound else { throw CustomSoundPackError.missingKeySound }
        return Inspection(audioFiles: audioFiles, hasReleaseSounds: hasReleaseSound)
    }

    private func displayName(for folder: URL) -> String {
        let metadataURL = folder.appendingPathComponent("manifest.json")
        if let data = try? Data(contentsOf: metadataURL, options: [.mappedIfSafe]),
           data.count <= 16_384,
           let metadata = try? JSONDecoder().decode(PackMetadata.self, from: data) {
            let name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return String(name.prefix(48)) }
        }
        let name = folder.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((name.isEmpty ? "Custom Pack" : name).prefix(48))
    }
}

enum CustomSoundAction: Equatable {
    case down
    case up
}

enum CustomSoundKind: Equatable {
    case key
    case space
    case delete
    case enter
    case mouse
}

enum CustomSoundName {
    static func category(for rawName: String) -> (action: CustomSoundAction, kind: CustomSoundKind) {
        let name = rawName.lowercased().replacingOccurrences(of: "-", with: "_")
        let isRelease = name.contains("release") || name.contains("key_up") || name.hasSuffix("_up")
        let action: CustomSoundAction = isRelease ? .up : .down
        let kind: CustomSoundKind
        if name.contains("space") {
            kind = .space
        } else if name.contains("delete") || name.contains("back") {
            kind = .delete
        } else if name.contains("enter") || name.contains("return") {
            kind = .enter
        } else if name.contains("mouse") || name.contains("click") {
            kind = .mouse
        } else {
            kind = .key
        }
        return (action, kind)
    }
}
