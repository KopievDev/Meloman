import Foundation

public struct LyricWord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var start: Timecode
    public var end: Timecode
    public var isHidden: Bool

    public init?(
        id: UUID = UUID(),
        text: String,
        start: Timecode,
        end: Timecode,
        isHidden: Bool = false
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, start < end else {
            return nil
        }
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.isHidden = isHidden
    }
}

public struct LyricLine: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var words: [LyricWord]

    public init(id: UUID = UUID(), words: [LyricWord] = []) {
        self.id = id
        self.words = words
    }
}
