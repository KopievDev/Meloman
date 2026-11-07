import Foundation
import MelomanDomain

/// Converts independently aligned ASR words to editable domain lines without
/// inventing approximate timings or changing immutable audio sources.
public enum RecognizedLyricsBuilder {
    public static func lines(
        from recognized: [RecognizedWord],
        duration: Timecode,
        maxWordsPerLine: Int = 7
    ) -> [LyricLine] {
        guard duration.microseconds > 0, maxWordsPerLine > 0 else { return [] }

        var result: [LyricLine] = []
        var current: [LyricWord] = []
        var lastEnd: Int64 = 0
        var lastSegment: Int?

        func finishLine() {
            if !current.isEmpty {
                result.append(LyricLine(words: current))
                current.removeAll()
            }
        }

        for source in recognized {
            let text = source.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  source.startSeconds.isFinite, source.endSeconds.isFinite,
                  source.startSeconds >= 0,
                  source.endSeconds > source.startSeconds
            else { continue }

            let startValue = source.startSeconds * 1_000_000
            let endValue = source.endSeconds * 1_000_000
            guard startValue < Double(duration.microseconds) else { continue }

            let startMicroseconds = Int64(max(0, startValue.rounded()))
            let endMicroseconds = Int64(min(Double(duration.microseconds), endValue.rounded()))
            guard endMicroseconds > startMicroseconds,
                  let start = Timecode(microseconds: startMicroseconds),
                  let end = Timecode(microseconds: endMicroseconds),
                  let word = LyricWord(text: text, start: start, end: end)
            else { continue }

            let longPause = startMicroseconds - lastEnd > 800_000
            if !current.isEmpty, current.count >= maxWordsPerLine || longPause || lastSegment != source.segment {
                finishLine()
            }

            current.append(word)
            lastEnd = endMicroseconds
            lastSegment = source.segment
        }

        finishLine()
        return result
    }
}
