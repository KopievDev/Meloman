import Foundation
import MelomanDomain

public struct KaraokeDisplayCue: Sendable {
    public let line: LyricLine
    public let row: KaraokeDisplayRow
    public let start: Timecode
    public let end: Timecode

    public init(line: LyricLine, row: KaraokeDisplayRow, start: Timecode, end: Timecode) {
        self.line = line
        self.row = row
        self.start = start
        self.end = end
    }
}

/// The same two-line layout is evaluated at word boundaries in MP4 export.
/// Adjacent segments with an unchanged line are merged to limit layer count.
public enum KaraokeDisplayTimeline {
    public static func cues(from lines: [LyricLine], duration: Timecode) -> [KaraokeDisplayCue] {
        let startTimes = lines.compactMap { $0.words.map(\.start).min() }
        let leadIns = startTimes.map { start in
            Timecode(microseconds: max(0, start.microseconds - 3_000_000)) ?? .zero
        }
        let boundaries = Set([Timecode.zero, duration] + leadIns + lines.flatMap { line in
            line.words.flatMap { [$0.start, $0.end] }
        }).filter { $0 <= duration }.sorted()

        var current: [KaraokeDisplayCue] = []
        var upcoming: [KaraokeDisplayCue] = []
        for index in 0 ..< max(0, boundaries.count - 1) {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            guard start < end else { continue }
            let frame = KaraokeDisplayEngine.frame(at: start, lines: lines)
            append(frame.current, row: .current, range: start ..< end, from: lines, to: &current)
            append(frame.upcoming, row: .upcoming, range: start ..< end, from: lines, to: &upcoming)
        }
        return current + upcoming
    }

    private static func append(
        _ frame: KaraokeFrame?,
        row: KaraokeDisplayRow,
        range: Range<Timecode>,
        from lines: [LyricLine],
        to cues: inout [KaraokeDisplayCue]
    ) {
        guard let frame, let line = lines.first(where: { $0.id == frame.lineID }) else { return }
        if let previous = cues.last, previous.line.id == frame.lineID, previous.end == range.lowerBound {
            cues[cues.count - 1] = KaraokeDisplayCue(
                line: line, row: row, start: previous.start, end: range.upperBound
            )
        } else {
            cues.append(KaraokeDisplayCue(
                line: line, row: row, start: range.lowerBound, end: range.upperBound
            ))
        }
    }
}
