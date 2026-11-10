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
    public var media: [MediaAsset]
    public var lyrics: [LyricLine]
    /// Per-media editable karaoke documents. Optional to decode projects from PR #2.
    public var karaokeDocuments: [KaraokeDocument]?
    /// Optional for compatibility with projects saved before image backgrounds.
    public var backgroundImages: [MediaBackgroundImage]?
    /// Separate optional metadata keeps older .meloman projects compatible.
    public var backgroundVideos: [MediaBackgroundVideo]?
    public var vocalRemoval: VocalRemovalConfiguration

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        tracks: [TimelineTrack] = [],
        media: [MediaAsset] = [],
        lyrics: [LyricLine] = [],
        karaokeDocuments: [KaraokeDocument]? = nil,
        backgroundImages: [MediaBackgroundImage]? = nil,
        backgroundVideos: [MediaBackgroundVideo]? = nil,
        vocalRemoval: VocalRemovalConfiguration = .init()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.tracks = tracks
        self.media = media
        self.lyrics = lyrics
        self.karaokeDocuments = karaokeDocuments
        self.backgroundImages = backgroundImages
        self.backgroundVideos = backgroundVideos
        self.vocalRemoval = vocalRemoval
    }
}
