import Foundation
import KaraokeEngine
import MelomanDomain
import XCTest

final class KaraokeExportTimelineTests: XCTestCase {
    func testExportCuesMatchKaraokePreviewIntervals() throws {
        let total = try XCTUnwrap(Timecode(microseconds: 10_000_000))
        let one = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        let two = try XCTUnwrap(Timecode(microseconds: 2_000_000))
        let four = try XCTUnwrap(Timecode(microseconds: 4_000_000))
        let w1 = try XCTUnwrap(LyricWord(text: "Эй,", start: one, end: two))
        let w2 = try XCTUnwrap(LyricWord(
            text: "друзья!",
            start: two,
            end: four,
            isHidden: true
        ))
        let line = LyricLine(words: [w1, w2])
        let cues = KaraokeExportTimeline.cues(from: [line], duration: total)

        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].line.words.map(\.text), ["Эй,", "друзья!"])
        XCTAssertTrue(cues[0].line.words[1].isHidden)
        XCTAssertEqual(cues[0].start, w1.start)
        XCTAssertEqual(cues[0].end, w2.end)

        let midpoint = try XCTUnwrap(Timecode(microseconds: 3_000_000))
        let frame = try XCTUnwrap(KaraokeEngine.frame(at: midpoint, lines: [line]))
        XCTAssertEqual(frame.lineID, cues[0].line.id)
        XCTAssertEqual(frame.words[0].progress, 1)
        XCTAssertEqual(frame.words[1].progress, 0.5)
    }

    func testInvalidAndEmptyLinesAreNotExported() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 3_000_000))
        let late = try XCTUnwrap(Timecode(microseconds: 4_000_000))
        let end = try XCTUnwrap(Timecode(microseconds: 5_000_000))
        let word = try XCTUnwrap(LyricWord(text: "Поздно", start: late, end: end))
        XCTAssertTrue(KaraokeExportTimeline.cues(
            from: [LyricLine(), LyricLine(words: [word])],
            duration: duration
        ).isEmpty)
    }
}
