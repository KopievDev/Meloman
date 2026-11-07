import Foundation
import MelomanDomain

public enum ProjectStoreError: LocalizedError {
    case wrongExtension
    case unsupportedVersion(Int)
    case invalidFileExtension(String)
    case missingSource(String)
    case missingMedia(String)

    public var errorDescription: String? {
        switch self {
        case .wrongExtension:
            "Проект должен иметь расширение .meloman."
        case let .unsupportedVersion(version):
            "Версия проекта \(version) не поддерживается."
        case let .invalidFileExtension(value):
            "Некорректное расширение медиаданных: \(value)."
        case let .missingSource(name):
            "Не удалось найти исходный файл: \(name)."
        case let .missingMedia(name):
            "Файл внутри проекта отсутствует: \(name)."
        }
    }
}

public struct ProjectBundle: Sendable {
    public let project: MelomanProject
    public let mediaURLs: [UUID: URL]

    public init(project: MelomanProject, mediaURLs: [UUID: URL]) {
        self.project = project
        self.mediaURLs = mediaURLs
    }
}

private struct ProjectManifest: Codable {
    let schemaVersion: Int
    let project: MelomanProject
}

/// Portable, non-destructive package store. Source media is copied into Media/.
/// Saving uses a new staging directory and restores the old package on failure.
public struct ProjectStore: Sendable {
    public static let packageExtension = "meloman"
    private static let schemaVersion = 1

    public init() {}

    @discardableResult
    public func save(_ bundle: ProjectBundle, to destination: URL) throws -> ProjectBundle {
        guard destination.pathExtension.lowercased() == Self.packageExtension else {
            throw ProjectStoreError.wrongExtension
        }

        let manager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(".meloman-\(UUID().uuidString)-staging", isDirectory: true)
        let mediaDirectory = staging.appendingPathComponent("Media", isDirectory: true)

        try manager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }

        var packagedURLs: [UUID: URL] = [:]
        for media in bundle.project.media {
            guard media.fileExtension.range(of: "^[a-z0-9]{1,8}$", options: .regularExpression) != nil else {
                throw ProjectStoreError.invalidFileExtension(media.fileExtension)
            }
            guard let source = bundle.mediaURLs[media.id], manager.fileExists(atPath: source.path) else {
                throw ProjectStoreError.missingSource(media.name)
            }

            let file = mediaDirectory.appendingPathComponent(media.packagedFilename)
            try manager.copyItem(at: source, to: file)
            packagedURLs[media.id] = destination
                .appendingPathComponent("Media", isDirectory: true)
                .appendingPathComponent(media.packagedFilename)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifest = ProjectManifest(schemaVersion: Self.schemaVersion, project: bundle.project)
        try encoder.encode(manifest).write(
            to: staging.appendingPathComponent("project.json"),
            options: .atomic
        )

        if manager.fileExists(atPath: destination.path) {
            let backup = parent.appendingPathComponent(".meloman-\(UUID().uuidString)-backup", isDirectory: true)
            try manager.moveItem(at: destination, to: backup)
            do {
                try manager.moveItem(at: staging, to: destination)
                try? manager.removeItem(at: backup)
            } catch {
                try? manager.moveItem(at: backup, to: destination)
                throw error
            }
        } else {
            try manager.moveItem(at: staging, to: destination)
        }

        return ProjectBundle(project: bundle.project, mediaURLs: packagedURLs)
    }

    public func open(at url: URL) throws -> ProjectBundle {
        guard url.pathExtension.lowercased() == Self.packageExtension else {
            throw ProjectStoreError.wrongExtension
        }

        let data = try Data(contentsOf: url.appendingPathComponent("project.json"))
        let manifest = try JSONDecoder().decode(ProjectManifest.self, from: data)
        guard manifest.schemaVersion == Self.schemaVersion else {
            throw ProjectStoreError.unsupportedVersion(manifest.schemaVersion)
        }

        var mediaURLs: [UUID: URL] = [:]
        for asset in manifest.project.media {
            guard asset.fileExtension.range(of: "^[a-z0-9]{1,8}$", options: .regularExpression) != nil else {
                throw ProjectStoreError.invalidFileExtension(asset.fileExtension)
            }
            let mediaURL = url
                .appendingPathComponent("Media", isDirectory: true)
                .appendingPathComponent(asset.packagedFilename)
            guard FileManager.default.fileExists(atPath: mediaURL.path) else {
                throw ProjectStoreError.missingMedia(asset.name)
            }
            mediaURLs[asset.id] = mediaURL
        }

        return ProjectBundle(project: manifest.project, mediaURLs: mediaURLs)
    }
}
