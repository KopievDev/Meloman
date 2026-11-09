import Foundation
import MelomanDomain

/// Line visibility intervals for offline export use the same bounds as KaraokeEngine.frame.
/// Invalid or empty lines are skipped instead of exporting flickering text.
public struct KaraokeExportCue: Sendable {
    public let line: LyricLine
    public let start: Timecode
    public let end: Timecode

    public init(line: LyricLine, start: Timecode, end: Timecode) {
        self.line = line
        self.start = start
        self.end = end
    }
}

public enum KaraokeExportTimeline {
    public static func cues(from lines: [LyricLine], duration: Timecode) -> [KaraokeExportCue] {
        lines.compactMap { line in
            guard let first = line.words.first,
                  let last = line.words.last,
                  first.start < last.end,
                  last.end <= duration
            else { return nil }
            return KaraokeExportCue(line: line, start: first.start, end: last.end)
        }
    }
}
