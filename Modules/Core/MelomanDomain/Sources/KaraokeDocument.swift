import Foundation

/// Karaoke lyrics for one imported source. Never modifies the original media.
public struct KaraokeDocument: Codable, Equatable, Identifiable, Sendable {
    public let mediaID: UUID
    public var lines: [LyricLine]

    public var id: UUID {
        mediaID
    }

    public init(mediaID: UUID, lines: [LyricLine] = []) {
        self.mediaID = mediaID
        self.lines = lines
    }
}

public extension MelomanProject {
    func karaokeLines(for mediaID: UUID) -> [LyricLine] {
        karaokeDocuments?.first(where: { $0.mediaID == mediaID })?.lines ?? []
    }

    mutating func setKaraokeLines(_ lines: [LyricLine], for mediaID: UUID) {
        var documents = karaokeDocuments ?? []
        if let index = documents.firstIndex(where: { $0.mediaID == mediaID }) {
            documents[index].lines = lines
        } else {
            documents.append(KaraokeDocument(mediaID: mediaID, lines: lines))
        }
        karaokeDocuments = documents
    }
}
