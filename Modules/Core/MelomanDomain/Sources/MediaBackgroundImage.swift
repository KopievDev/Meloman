import Foundation

/// A still image behind karaoke for one audio-only media item.
/// The image is copied to Backgrounds/ when the .meloman project is saved.
public struct MediaBackgroundImage: Codable, Equatable, Sendable {
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
    func backgroundImage(for mediaID: UUID) -> MediaBackgroundImage? {
        backgroundImages?.first(where: { $0.mediaID == mediaID })
    }

    mutating func setBackgroundImage(_ background: MediaBackgroundImage?, for mediaID: UUID) {
        var images = backgroundImages ?? []
        images.removeAll(where: { $0.mediaID == mediaID })
        if let background {
            images.append(background)
        }
        backgroundImages = images
    }
}
