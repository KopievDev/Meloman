import Foundation

/// A silent looping background video for an audio-only media item.
/// Its original sound is never mixed into the karaoke soundtrack.
public struct MediaBackgroundVideo: Codable, Equatable, Sendable {
    public let mediaID: UUID
    public let fileExtension: String

    public init(mediaID: UUID, fileExtension: String) {
        self.mediaID = mediaID
        self.fileExtension = fileExtension.lowercased()
    }

    public var packagedFilename: String {
        "\(mediaID.uuidString).\(fileExtension)"
    }
}

public extension MelomanProject {
    func backgroundVideo(for mediaID: UUID) -> MediaBackgroundVideo? {
        backgroundVideos?.first(where: { $0.mediaID == mediaID })
    }

    mutating func setBackgroundVideo(_ video: MediaBackgroundVideo?, for mediaID: UUID) {
        var videos = backgroundVideos ?? []
        videos.removeAll(where: { $0.mediaID == mediaID })
        if let video {
            videos.append(video)
        }
        backgroundVideos = videos
    }
}
