import Foundation
import MelomanDomain

/// Makes a coarse manual draft when the user pastes complete lyrics.
/// IMPORTANT: timings are evenly estimated — not AI transcription or alignment.
public enum LyricsDraftBuilder {
    public static func build(text: String, duration: Timecode) -> [LyricLine] {
        let rawLines = text
            .components(separatedBy: .newlines)
            .map { line in line.split(whereSeparator: \.isWhitespace).map(String.init) }
            .filter { !$0.isEmpty }

        let count = rawLines.reduce(0) { $0 + $1.count }
        guard count > 0, Int64(count) <= duration.microseconds else { return [] }

        let total = Int64(count)
        let step = duration.microseconds / total
        let remainder = duration.microseconds % total
        var position: Int64 = 0

        return rawLines.map { pieces in
            let words = pieces.compactMap { piece -> LyricWord? in
                let start = step * position + min(position, remainder)
                position += 1
                let end = step * position + min(position, remainder)
                guard let startTime = Timecode(microseconds: start),
                      let endTime = Timecode(microseconds: end)
                else { return nil }
                return LyricWord(text: piece, start: startTime, end: endTime)
            }
            return LyricLine(words: words)
        }
    }
}
