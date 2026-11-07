import Foundation

public enum TrackKind: String, CaseIterable, Codable, Sendable {
    case video
    case background
    case image
    case gif
    case karaoke
    case audio
}

public struct TimelineClip: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var start: Timecode
    public var duration: Timecode
    public var mediaID: UUID?

    public init(
        id: UUID = UUID(),
        start: Timecode,
        duration: Timecode,
        mediaID: UUID? = nil
    ) {
        self.id = id
        self.start = start
        self.duration = duration
        self.mediaID = mediaID
    }
}

public struct TimelineTrack: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: TrackKind
    public var clips: [TimelineClip]
    public var isHidden: Bool
    public var isMuted: Bool

    public init(
        id: UUID = UUID(),
        kind: TrackKind,
        clips: [TimelineClip] = [],
        isHidden: Bool = false,
        isMuted: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.clips = clips
        self.isHidden = isHidden
        self.isMuted = isMuted
    }
}
