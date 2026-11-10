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
        // Evaluate the same line selection as preview at every word boundary.
        // This also splits overlapping cues rather than drawing two lines
        // simultaneously in the exported MP4.
        let words = lines.flatMap(\.words)
        let boundaries = Set([Timecode.zero, duration] + words.flatMap { [$0.start, $0.end] })
            .filter { $0 <= duration }
            .sorted()

        var cues: [KaraokeExportCue] = []
        for index in 0 ..< max(0, boundaries.count - 1) {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            guard start < end,
                  let frame = KaraokeEngine.frame(at: start, lines: lines),
                  let line = lines.first(where: { $0.id == frame.lineID })
            else { continue }

            if let previous = cues.last, previous.line.id == line.id, previous.end == start {
                cues[cues.count - 1] = KaraokeExportCue(line: line, start: previous.start, end: end)
            } else {
                cues.append(KaraokeExportCue(line: line, start: start, end: end))
            }
        }
        return cues
    }
}
