import Foundation

/// Karaoke lyrics for one imported source. Never modifies the original media.
public struct KaraokeDocument: Codable, Equatable, Identifiable, Sendable {
    public let mediaID: UUID
    public var lines: [LyricLine]
    /// Optional for compatibility with existing .meloman projects.
    public var style: KaraokeStyle?

    public var id: UUID {
        mediaID
    }

    public init(mediaID: UUID, lines: [LyricLine] = [], style: KaraokeStyle? = nil) {
        self.mediaID = mediaID
        self.lines = lines
        self.style = style
    }
}

public extension MelomanProject {
    func karaokeLines(for mediaID: UUID) -> [LyricLine] {
        karaokeDocuments?.first(where: { $0.mediaID == mediaID })?.lines ?? []
    }

    func karaokeStyle(for mediaID: UUID) -> KaraokeStyle {
        karaokeDocuments?.first(where: { $0.mediaID == mediaID })?.style?.sanitized() ?? .init()
    }

    mutating func setKaraokeStyle(_ style: KaraokeStyle, for mediaID: UUID) {
        var documents = karaokeDocuments ?? []
        if let index = documents.firstIndex(where: { $0.mediaID == mediaID }) {
            documents[index].style = style.sanitized()
        } else {
            documents.append(KaraokeDocument(mediaID: mediaID, style: style.sanitized()))
        }
        karaokeDocuments = documents
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
