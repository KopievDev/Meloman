import Foundation

public enum MediaKind: String, Codable, Sendable {
    case audio
    case video
}

/// Describes an imported, immutable source asset.
/// Package media is addressed by a UUID-based filename, never by the original path.
public struct MediaAsset: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let fileExtension: String
    public let kind: MediaKind
    public let duration: Timecode

    public init(
        id: UUID = UUID(),
        name: String,
        fileExtension: String,
        kind: MediaKind,
        duration: Timecode
    ) {
        self.id = id
        self.name = name
        self.fileExtension = fileExtension.lowercased()
        self.kind = kind
        self.duration = duration
    }

    public var packagedFilename: String {
        "\(id.uuidString).\(fileExtension)"
    }
}
