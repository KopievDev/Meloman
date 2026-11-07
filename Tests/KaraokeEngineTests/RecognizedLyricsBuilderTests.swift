import Foundation
import KaraokeEngine
import MelomanDomain
import XCTest

final class RecognizedLyricsBuilderTests: XCTestCase {
    func testRecognizedWordsKeepRealOffsetsAndSplitLines() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 10_000_000))
        let words = [
            RecognizedWord(text: "Привет", startSeconds: 0.4, endSeconds: 1.2, segment: 0),
            RecognizedWord(text: "мир", startSeconds: 1.3, endSeconds: 1.9, segment: 0),
            RecognizedWord(text: "Как", startSeconds: 3.5, endSeconds: 4.0, segment: 0),
            RecognizedWord(text: "дела", startSeconds: 4.1, endSeconds: 4.8, segment: 0),
        ]

        let lines = RecognizedLyricsBuilder.lines(from: words, duration: duration)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].words.map(\.text), ["Привет", "мир"])
        XCTAssertEqual(lines[1].words.map(\.text), ["Как", "дела"])
        XCTAssertEqual(lines[0].words[0].start.microseconds, 400_000)
        XCTAssertEqual(lines[0].words[0].end.microseconds, 1_200_000)
    }

    func testInvalidAndOutOfRangeWordsAreIgnored() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 5_000_000))
        let inputs = [
            RecognizedWord(text: "", startSeconds: 0, endSeconds: 1, segment: 0),
            RecognizedWord(text: "oops", startSeconds: -.infinity, endSeconds: 1, segment: 0),
            RecognizedWord(text: "later", startSeconds: 6, endSeconds: 7, segment: 0),
            RecognizedWord(text: "ok", startSeconds: 4.8, endSeconds: 6, segment: 0),
        ]
        let lines = RecognizedLyricsBuilder.lines(from: inputs, duration: duration)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].words[0].text, "ok")
        XCTAssertEqual(lines[0].words[0].end.microseconds, 5_000_000)
    }

    func testMaxWordsPerLineAndSegmentChanges() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 20_000_000))
        let words = [
            RecognizedWord(text: "one", startSeconds: 0.1, endSeconds: 0.4, segment: 0),
            RecognizedWord(text: "two", startSeconds: 0.5, endSeconds: 0.8, segment: 0),
            RecognizedWord(text: "three", startSeconds: 0.9, endSeconds: 1.2, segment: 1),
        ]
        let lines = RecognizedLyricsBuilder.lines(from: words, duration: duration, maxWordsPerLine: 2)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].words.count, 2)
        XCTAssertEqual(lines[1].words[0].text, "three")
    }
}
