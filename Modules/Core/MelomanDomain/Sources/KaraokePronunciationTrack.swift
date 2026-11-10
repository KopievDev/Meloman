import Foundation

/// A manual or automatically drafted Cyrillic pronunciation of one source word.
/// Original text, timing, translation and pronunciation are independent.
public struct PronunciationWord: Codable, Equatable, Sendable {
    public let sourceWordID: UUID
    public var text: String

    public init(sourceWordID: UUID, text: String) {
        self.sourceWordID = sourceWordID
        self.text = text
    }
}

/// K2 does not duplicate word timestamps: each entry refers to a K1 word UUID.
public struct KaraokePronunciationTrack: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var words: [PronunciationWord]

    public init(isEnabled: Bool = false, words: [PronunciationWord] = []) {
        self.isEnabled = isEnabled
        self.words = words
    }

    public func text(for wordID: UUID) -> String? {
        words.first(where: { $0.sourceWordID == wordID })?.text
    }

    public mutating func setText(_ text: String, for wordID: UUID) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        words.removeAll(where: { $0.sourceWordID == wordID })
        if !value.isEmpty {
            words.append(PronunciationWord(sourceWordID: wordID, text: value))
        }
    }

    public mutating func retainWords(in lines: [LyricLine]) {
        let ids = Set(lines.flatMap(\.words).map(\.id))
        words.removeAll(where: { !ids.contains($0.sourceWordID) })
    }

    public func lineText(for line: LyricLine) -> String {
        line.words.map { word in
            word.isHidden ? "____" : (text(for: word.id) ?? "")
        }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
