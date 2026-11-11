import Foundation
import MelomanDomain

public struct KaraokeDisplayCue: Sendable {
    public let line: LyricLine
    public let row: KaraokeDisplayRow
    public let slot: KaraokeDisplaySlot
    public let start: Timecode
    public let end: Timecode

    public init(
        line: LyricLine,
        row: KaraokeDisplayRow,
        slot: KaraokeDisplaySlot,
        start: Timecode,
        end: Timecode
    ) {
        self.line = line
        self.row = row
        self.slot = slot
        self.start = start
        self.end = end
    }
}

/// The same alternating two-slot layout is evaluated at word boundaries in MP4 export.
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
            append(
                frame.current, placement: (.current, frame.currentSlot),
                range: start ..< end, from: lines, to: &current
            )
            append(
                frame.upcoming, placement: (.upcoming, frame.upcomingSlot),
                range: start ..< end, from: lines, to: &upcoming
            )
        }
        return current + upcoming
    }

    private static func append(
        _ frame: KaraokeFrame?,
        placement: (role: KaraokeDisplayRow, slot: KaraokeDisplaySlot),
        range: Range<Timecode>,
        from lines: [LyricLine],
        to cues: inout [KaraokeDisplayCue]
    ) {
        guard let frame, let line = lines.first(where: { $0.id == frame.lineID }) else { return }
        let sameLine = cues.last?.line.id == frame.lineID
        let sameSlot = cues.last?.slot == placement.slot
        let contiguous = cues.last?.end == range.lowerBound
        if sameLine, sameSlot, contiguous {
            let start = cues[cues.count - 1].start
            cues[cues.count - 1] = KaraokeDisplayCue(
                line: line, row: placement.role, slot: placement.slot,
                start: start, end: range.upperBound
            )
        } else {
            cues.append(KaraokeDisplayCue(
                line: line, row: placement.role, slot: placement.slot,
                start: range.lowerBound, end: range.upperBound
            ))
        }
    }
}
