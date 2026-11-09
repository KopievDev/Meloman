import Foundation
import KaraokeEngine
import MelomanDomain
import XCTest

final class LyricsAlignmentApplierTests: XCTestCase {
    func testCorrectReferenceTextIsPreservedIncludingSlangAndLineBreaks() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 12_000_000))
        let oneSecond = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        let twoSeconds = try XCTUnwrap(Timecode(microseconds: 2_000_000))
        let first = try XCTUnwrap(LyricWord(text: "Эй,", start: .zero, end: oneSecond))
        let second = try XCTUnwrap(LyricWord(
            text: "пацаны!",
            start: oneSecond,
            end: twoSeconds,
            isHidden: true
        ))
        let words = [first, second]
        let line = LyricLine(words: words)
        let alignment = AcousticLyricsAlignment(aligned: [
            AcousticWordTiming(
                id: words[0].id, startSeconds: 3.2, endSeconds: 3.6, confidence: 0.9
            ),
            AcousticWordTiming(
                id: words[1].id, startSeconds: 3.7, endSeconds: 4.5, confidence: 0.15
            ),
        ], unresolved: [])

        let result = LyricsAlignmentApplier.apply(alignment, to: [line], duration: duration)
        XCTAssertEqual(result.updatedWords, 2)
        XCTAssertEqual(result.lowConfidenceWords, 1)
        XCTAssertEqual(result.lines[0].words.map(\.text), ["Эй,", "пацаны!"])
        XCTAssertEqual(result.lines[0].id, line.id)
        XCTAssertEqual(result.lines[0].words.map(\.id), words.map(\.id))
        XCTAssertTrue(result.lines[0].words[1].isHidden)
        XCTAssertEqual(result.lines[0].words[0].start.microseconds, 3_200_000)
        XCTAssertEqual(result.lines[0].words[1].alignmentConfidence, 0.15)
    }

    func testUnmatchedAndInvalidTimingCannotReplaceWords() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 10_000_000))
        let lyrics = LyricsDraftBuilder.build(text: "Раз два три", duration: duration)
        let words = lyrics[0].words
        let alignment = AcousticLyricsAlignment(aligned: [
            AcousticWordTiming(id: words[0].id, startSeconds: -1, endSeconds: 2, confidence: 0.9),
            AcousticWordTiming(id: words[1].id, startSeconds: 2, endSeconds: 11, confidence: 0.9),
            AcousticWordTiming(id: words[2].id, startSeconds: 5, endSeconds: 6, confidence: .nan),
        ], unresolved: [])

        let result = LyricsAlignmentApplier.apply(alignment, to: lyrics, duration: duration)
        XCTAssertEqual(result.updatedWords, 0)
        XCTAssertEqual(result.unchangedWords, 3)
        XCTAssertEqual(result.lines, lyrics)
    }

    func testOlderProjectDecodesWithoutAlignmentMetadata() throws {
        let oneSecond = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        let value = try XCTUnwrap(LyricWord(text: "Снова", start: .zero, end: oneSecond))
        let current = try JSONEncoder().encode(value)
        let raw = try XCTUnwrap(String(data: current, encoding: .utf8))
        let older = raw.replacingOccurrences(of: "\"alignmentConfidence\":null,", with: "")
            .replacingOccurrences(of: ",\"alignmentConfidence\":null", with: "")
        let decoded = try JSONDecoder().decode(LyricWord.self, from: Data(older.utf8))
        XCTAssertNil(decoded.alignmentConfidence)
        XCTAssertEqual(decoded.text, value.text)
    }
}
