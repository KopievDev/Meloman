import Foundation

/// Word dragging operates on the source K1 words. K2 pronunciation inherits
/// those exact timings through its shared word IDs.
public enum LyricTimingEditMode: Equatable, Sendable {
    case moveWord
    case trimStart
    case trimEnd
    case moveLine
}

/// Pure timeline edit: the caller always applies a delta to the original
/// snapshot, not to previous drag updates, to avoid accumulated rounding drift.
public enum LyricTimingEditor {
    public static let minimumWordMicroseconds: Int64 = 50_000

    public static func applying(
        _ mode: LyricTimingEditMode,
        to wordID: UUID,
        in lines: [LyricLine],
        deltaMicroseconds: Int64,
        mediaDuration: Timecode
    ) -> [LyricLine]? {
        guard mediaDuration.microseconds > 0,
              let lineIndex = lines.firstIndex(where: { $0.words.contains(where: { $0.id == wordID }) }),
              let wordIndex = lines[lineIndex].words.firstIndex(where: { $0.id == wordID })
        else { return nil }

        let words = lines[lineIndex].words
        guard words.allSatisfy({ $0.start < $0.end && $0.end <= mediaDuration }) else { return nil }
        let selected = words[wordIndex]
        let start = selected.start.microseconds
        let end = selected.end.microseconds

        let minimumDelta: Int64
        let maximumDelta: Int64
        switch mode {
        case .moveWord:
            minimumDelta = -start
            maximumDelta = mediaDuration.microseconds - end
        case .trimStart:
            minimumDelta = -start
            let minimum = min(minimumWordMicroseconds, end - start)
            maximumDelta = end - minimum - start
        case .trimEnd:
            let minimum = min(minimumWordMicroseconds, end - start)
            minimumDelta = start + minimum - end
            maximumDelta = mediaDuration.microseconds - end
        case .moveLine:
            guard let first = words.map(\.start.microseconds).min(),
                  let last = words.map(\.end.microseconds).max()
            else { return nil }
            minimumDelta = -first
            maximumDelta = mediaDuration.microseconds - last
        }

        let offset = max(minimumDelta, min(maximumDelta, deltaMicroseconds))
        guard offset != 0 else { return lines }

        var changed = lines
        if mode == .moveLine {
            for index in words.indices {
                changed[lineIndex].words[index].start = Timecode(
                    microseconds: words[index].start.microseconds + offset
                )!
                changed[lineIndex].words[index].end = Timecode(
                    microseconds: words[index].end.microseconds + offset
                )!
            }
        } else {
            switch mode {
            case .moveWord:
                changed[lineIndex].words[wordIndex].start = Timecode(microseconds: start + offset)!
                changed[lineIndex].words[wordIndex].end = Timecode(microseconds: end + offset)!
            case .trimStart:
                changed[lineIndex].words[wordIndex].start = Timecode(microseconds: start + offset)!
            case .trimEnd:
                changed[lineIndex].words[wordIndex].end = Timecode(microseconds: end + offset)!
            case .moveLine:
                break
            }
        }
        return changed
    }

    /// Snap the dragged boundary (not merely the delta) to the nearest grid
    /// line, preventing repeated drags from accumulating off-grid offsets.
    public static func snappedDelta(
        from boundary: Timecode,
        proposedDelta: Int64,
        intervalMicroseconds: Int64 = 50_000
    ) -> Int64 {
        guard intervalMicroseconds > 0 else { return proposedDelta }
        let target = Double(boundary.microseconds) + Double(proposedDelta)
        let snapped = (target / Double(intervalMicroseconds)).rounded() * Double(intervalMicroseconds)
        guard snapped >= Double(Int64.min), snapped < Double(Int64.max) else {
            return proposedDelta
        }
        let value = Int64(snapped)
        let (delta, overflow) = value.subtractingReportingOverflow(boundary.microseconds)
        return overflow ? proposedDelta : delta
    }
}
