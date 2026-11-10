import Foundation
import MelomanDomain

public struct KaraokeWordFrame: Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let progress: Double
    public let isHidden: Bool

    public init(id: UUID, text: String, progress: Double, isHidden: Bool) {
        self.id = id
        self.text = text
        self.progress = progress
        self.isHidden = isHidden
    }
}

public struct KaraokeFrame: Equatable, Sendable {
    public let lineID: UUID
    public let words: [KaraokeWordFrame]

    public init(lineID: UUID, words: [KaraokeWordFrame]) {
        self.lineID = lineID
        self.words = words
    }
}

/// Stateless evaluation: the same playhead and lyrics always yield the same word fills.
/// This is shared semantic timing for preview and future offline export.
public enum KaraokeEngine {
    public static func frame(at playhead: Timecode, lines: [LyricLine]) -> KaraokeFrame? {
        // CTC aligns words independently. Their times may not match the textual
        // order, so first.start / last.end can accidentally hide a whole line.
        let active = lines.compactMap { line -> (line: LyricLine, start: Timecode)? in
            let latest = line.words
                .filter { playhead >= $0.start && playhead < $0.end }
                .map(\.start)
                .max()
            guard let latest else { return nil }
            return (line, latest)
        }.max { $0.start < $1.start }?.line

        let line = active ?? lines.compactMap { line -> (line: LyricLine, start: Timecode)? in
            guard let first = line.words.map(\.start).min(),
                  let last = line.words.map(\.end).max(),
                  playhead >= first, playhead < last
            else { return nil }
            return (line, first)
        }.max { $0.start < $1.start }?.line

        guard let line else { return nil }
        let words = line.words.map { word in
            KaraokeWordFrame(
                id: word.id,
                text: word.text,
                progress: progress(of: word, at: playhead),
                isHidden: word.isHidden
            )
        }
        return KaraokeFrame(lineID: line.id, words: words)
    }

    public static func progress(of word: LyricWord, at playhead: Timecode) -> Double {
        guard playhead > word.start else { return 0 }
        guard playhead < word.end else { return 1 }
        let elapsed = Double(playhead.microseconds - word.start.microseconds)
        let duration = Double(word.end.microseconds - word.start.microseconds)
        return min(1, max(0, elapsed / duration))
    }
}
