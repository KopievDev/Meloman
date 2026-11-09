import Foundation
import MelomanDomain

public struct AppliedLyricsAlignment: Sendable {
    public let lines: [LyricLine]
    public let updatedWords: Int
    public let lowConfidenceWords: Int
    public let unchangedWords: Int

    public init(lines: [LyricLine], updatedWords: Int, lowConfidenceWords: Int, unchangedWords: Int) {
        self.lines = lines
        self.updatedWords = updatedWords
        self.lowConfidenceWords = lowConfidenceWords
        self.unchangedWords = unchangedWords
    }
}

/// Replaces timing only; retains every original word, punctuation, line and UUID.
/// Unmatched or invalid alignments keep the user's existing timing.
public enum LyricsAlignmentApplier {
    public static func apply(
        _ alignment: AcousticLyricsAlignment,
        to reference: [LyricLine],
        duration: Timecode
    ) -> AppliedLyricsAlignment {
        guard alignment.schemaVersion == 1, duration.microseconds > 0 else {
            return AppliedLyricsAlignment(
                lines: reference,
                updatedWords: 0,
                lowConfidenceWords: 0,
                unchangedWords: reference.reduce(0) { $0 + $1.words.count }
            )
        }

        var lookup: [UUID: AcousticWordTiming] = [:]
        for timing in alignment.aligned where lookup[timing.id] == nil {
            lookup[timing.id] = timing
        }

        var lines = reference
        var updated = 0
        var uncertain = 0
        var unchanged = 0
        for lineIndex in lines.indices {
            for wordIndex in lines[lineIndex].words.indices {
                let current = lines[lineIndex].words[wordIndex]
                guard let timing = lookup[current.id],
                      timing.startSeconds.isFinite,
                      timing.endSeconds.isFinite,
                      timing.confidence.isFinite,
                      (0 ... 1).contains(timing.confidence),
                      timing.startSeconds >= 0,
                      timing.startSeconds < timing.endSeconds,
                      timing.endSeconds * 1_000_000 <= Double(duration.microseconds),
                      let start = Timecode(microseconds: Int64((timing.startSeconds * 1_000_000).rounded())),
                      let end = Timecode(microseconds: Int64((timing.endSeconds * 1_000_000).rounded())),
                      start < end
                else {
                    unchanged += 1
                    continue
                }
                lines[lineIndex].words[wordIndex].start = start
                lines[lineIndex].words[wordIndex].end = end
                lines[lineIndex].words[wordIndex].alignmentConfidence = timing.confidence
                updated += 1
                if timing.confidence < 0.25 {
                    uncertain += 1
                }
            }
        }
        return AppliedLyricsAlignment(
            lines: lines,
            updatedWords: updated,
            lowConfidenceWords: uncertain,
            unchangedWords: unchanged
        )
    }
}
