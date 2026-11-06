import Foundation

/// The original source media is immutable. Effect selections refer to derived media.
public struct VocalRemovalConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }
}

public struct MelomanProject: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public let createdAt: Date
    public var tracks: [TimelineTrack]
    public var lyrics: [LyricLine]
    public var vocalRemoval: VocalRemovalConfiguration

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        tracks: [TimelineTrack] = [],
        lyrics: [LyricLine] = [],
        vocalRemoval: VocalRemovalConfiguration = .init()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.tracks = tracks
        self.lyrics = lyrics
        self.vocalRemoval = vocalRemoval
    }
}
