import Foundation
import MelomanDomain

public enum KaraokeDisplayRow: Equatable, Sendable {
    case current
    case upcoming
}

/// Fixed physical screen positions. The next phrase never jumps to a new slot
/// when it becomes current: yellow highlighting moves between the two slots.
public enum KaraokeDisplaySlot: Equatable, Sendable {
    case upper
    case lower

    public var opposite: KaraokeDisplaySlot {
        self == .upper ? .lower : .upper
    }
}

public struct KaraokeDisplayFrame: Equatable, Sendable {
    public let current: KaraokeFrame?
    public let upcoming: KaraokeFrame?
    public let currentSlot: KaraokeDisplaySlot

    public var upcomingSlot: KaraokeDisplaySlot {
        currentSlot.opposite
    }

    public init(
        current: KaraokeFrame?,
        upcoming: KaraokeFrame?,
        currentSlot: KaraokeDisplaySlot = .upper
    ) {
        self.current = current
        self.upcoming = upcoming
        self.currentSlot = currentSlot
    }
}

/// Alternating two-slot display: current text stays in the same physical
/// position when it becomes active. Both preview and export use this selector.
public enum KaraokeDisplayEngine {
    private static let leadInMicroseconds: Int64 = 3_000_000

    public static func frame(at playhead: Timecode, lines: [LyricLine]) -> KaraokeDisplayFrame {
        let ordered = lines.enumerated().compactMap { index, line -> LineSpan? in
            guard let start = line.words.map(\.start).min(),
                  let end = line.words.map(\.end).max(),
                  start < end
            else { return nil }
            return LineSpan(line: line, originalIndex: index, start: start, end: end)
        }.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.originalIndex < rhs.originalIndex : lhs.start < rhs.start
        }

        guard let first = ordered.first,
              playhead.microseconds >= first.start.microseconds - leadInMicroseconds
        else { return KaraokeDisplayFrame(current: nil, upcoming: nil) }

        let startedIndex = ordered.lastIndex(where: { $0.start <= playhead })
        let activeID = KaraokeEngine.frame(at: playhead, lines: lines)?.lineID
        let activeIndex = ordered.firstIndex(where: { $0.line.id == activeID })
        let index = max(startedIndex ?? 0, activeIndex ?? 0)
        let selected = ordered[index]

        // Don't leave the final line on-screen indefinitely after the song ends.
        if index == ordered.count - 1, playhead >= selected.end {
            return KaraokeDisplayFrame(current: nil, upcoming: nil)
        }

        let next = index + 1 < ordered.count ? ordered[index + 1].line : nil
        return KaraokeDisplayFrame(
            current: KaraokeEngine.frame(for: selected.line, at: playhead),
            upcoming: next.map { KaraokeEngine.frame(for: $0, at: .zero) },
            currentSlot: index.isMultiple(of: 2) ? .upper : .lower
        )
    }

    private struct LineSpan {
        let line: LyricLine
        let originalIndex: Int
        let start: Timecode
        let end: Timecode
    }
}
