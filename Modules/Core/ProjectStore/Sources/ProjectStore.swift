import Foundation
import MelomanDomain

public enum ProjectStoreError: LocalizedError {
    case wrongExtension
    case unsupportedVersion(Int)
    case invalidFileExtension(String)
    case missingSource(String)
    case missingMedia(String)
    case invalidBackgroundExtension(String)
    case missingBackground(String)
    case invalidBackgroundVideoExtension(String)
    case missingBackgroundVideo(String)

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
        case let .invalidBackgroundExtension(value):
            "Неподдерживаемое расширение фона: \(value)."
        case let .missingBackground(name):
            "Не удалось найти изображение фона: \(name)."
        case let .invalidBackgroundVideoExtension(value):
            "Неподдерживаемое расширение видеофона: \(value)."
        case let .missingBackgroundVideo(name):
            "Не удалось найти видеофон: \(name)."
        }
    }
}

public struct ProjectBundle: Sendable {
    public let project: MelomanProject
    public let mediaURLs: [UUID: URL]
    public let backgroundURLs: [UUID: URL]
    public let backgroundVideoURLs: [UUID: URL]

    public init(
        project: MelomanProject,
        mediaURLs: [UUID: URL],
        backgroundURLs: [UUID: URL] = [:],
        backgroundVideoURLs: [UUID: URL] = [:]
    ) {
        self.project = project
        self.mediaURLs = mediaURLs
        self.backgroundURLs = backgroundURLs
        self.backgroundVideoURLs = backgroundVideoURLs
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
        let backgroundsDirectory = staging.appendingPathComponent("Backgrounds", isDirectory: true)
        let videosDirectory = staging.appendingPathComponent("BackgroundVideos", isDirectory: true)

        try manager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        try manager.createDirectory(at: backgroundsDirectory, withIntermediateDirectories: true)
        try manager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }

        let packagedURLs = try stageMedia(bundle, in: mediaDirectory, destination: destination)
        let packagedBackgroundURLs = try stageBackgrounds(bundle, in: backgroundsDirectory, destination: destination)
        let packagedVideoURLs = try stageBackgroundVideos(bundle, in: videosDirectory, destination: destination)

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

        return ProjectBundle(
            project: bundle.project,
            mediaURLs: packagedURLs,
            backgroundURLs: packagedBackgroundURLs,
            backgroundVideoURLs: packagedVideoURLs
        )
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

        var backgroundURLs: [UUID: URL] = [:]
        for background in manifest.project.backgroundImages ?? [] {
            guard ["png", "jpg", "jpeg", "heic"].contains(background.fileExtension) else {
                throw ProjectStoreError.invalidBackgroundExtension(background.fileExtension)
            }
            let file = url
                .appendingPathComponent("Backgrounds", isDirectory: true)
                .appendingPathComponent(background.packagedFilename)
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw ProjectStoreError.missingBackground(background.packagedFilename)
            }
            backgroundURLs[background.mediaID] = file
        }

        var backgroundVideoURLs: [UUID: URL] = [:]
        for video in manifest.project.backgroundVideos ?? [] {
            guard ["mp4", "mov", "m4v"].contains(video.fileExtension) else {
                throw ProjectStoreError.invalidBackgroundVideoExtension(video.fileExtension)
            }
            let file = url
                .appendingPathComponent("BackgroundVideos", isDirectory: true)
                .appendingPathComponent(video.packagedFilename)
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw ProjectStoreError.missingBackgroundVideo(video.packagedFilename)
            }
            backgroundVideoURLs[video.mediaID] = file
        }

        return ProjectBundle(
            project: manifest.project,
            mediaURLs: mediaURLs,
            backgroundURLs: backgroundURLs,
            backgroundVideoURLs: backgroundVideoURLs
        )
    }

    private func stageMedia(
        _ bundle: ProjectBundle,
        in directory: URL,
        destination: URL
    ) throws -> [UUID: URL] {
        let manager = FileManager.default
        var packagedURLs: [UUID: URL] = [:]
        for media in bundle.project.media {
            guard media.fileExtension.range(of: "^[a-z0-9]{1,8}$", options: .regularExpression) != nil else {
                throw ProjectStoreError.invalidFileExtension(media.fileExtension)
            }
            guard let source = bundle.mediaURLs[media.id], manager.fileExists(atPath: source.path) else {
                throw ProjectStoreError.missingSource(media.name)
            }

            let file = directory.appendingPathComponent(media.packagedFilename)
            try manager.copyItem(at: source, to: file)
            packagedURLs[media.id] = destination
                .appendingPathComponent("Media", isDirectory: true)
                .appendingPathComponent(media.packagedFilename)
        }
        return packagedURLs
    }

    private func stageBackgrounds(
        _ bundle: ProjectBundle,
        in directory: URL,
        destination: URL
    ) throws -> [UUID: URL] {
        let manager = FileManager.default
        var packagedBackgroundURLs: [UUID: URL] = [:]
        for background in bundle.project.backgroundImages ?? [] {
            guard ["png", "jpg", "jpeg", "heic"].contains(background.fileExtension) else {
                throw ProjectStoreError.invalidBackgroundExtension(background.fileExtension)
            }
            guard let source = bundle.backgroundURLs[background.mediaID],
                  manager.fileExists(atPath: source.path)
            else {
                throw ProjectStoreError.missingBackground(background.packagedFilename)
            }

            let file = directory.appendingPathComponent(background.packagedFilename)
            try manager.copyItem(at: source, to: file)
            packagedBackgroundURLs[background.mediaID] = destination
                .appendingPathComponent("Backgrounds", isDirectory: true)
                .appendingPathComponent(background.packagedFilename)
        }
        return packagedBackgroundURLs
    }

    private func stageBackgroundVideos(
        _ bundle: ProjectBundle,
        in directory: URL,
        destination: URL
    ) throws -> [UUID: URL] {
        let manager = FileManager.default
        var result: [UUID: URL] = [:]
        for video in bundle.project.backgroundVideos ?? [] {
            guard ["mp4", "mov", "m4v"].contains(video.fileExtension) else {
                throw ProjectStoreError.invalidBackgroundVideoExtension(video.fileExtension)
            }
            guard let source = bundle.backgroundVideoURLs[video.mediaID],
                  manager.fileExists(atPath: source.path)
            else {
                throw ProjectStoreError.missingBackgroundVideo(video.packagedFilename)
            }

            try manager.copyItem(at: source, to: directory.appendingPathComponent(video.packagedFilename))
            result[video.mediaID] = destination
                .appendingPathComponent("BackgroundVideos", isDirectory: true)
                .appendingPathComponent(video.packagedFilename)
        }
        return result
    }
}
