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

    func testExportIncludesUnorderedAIAlignedWords() throws {
        func word(_ text: String, _ from: Int64, _ until: Int64) throws -> LyricWord {
            try XCTUnwrap(LyricWord(
                text: text,
                start: XCTUnwrap(Timecode(microseconds: from)),
                end: XCTUnwrap(Timecode(microseconds: until))
            ))
        }
        let line = try LyricLine(words: [
            word("Первый", 30_000_000, 30_300_000),
            word("Второй", 29_575_000, 30_056_000),
        ])
        let duration = try XCTUnwrap(Timecode(microseconds: 33_000_000))
        let cues = KaraokeExportTimeline.cues(from: [line], duration: duration)
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].start.microseconds, 29_575_000)
        XCTAssertEqual(cues[0].end.microseconds, 30_300_000)
    }

    func testOverlappingExportCuesDoNotDisplayTwoLinesTogether() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 8_000_000))
        let previous = try XCTUnwrap(LyricWord(
            text: "Одна",
            start: XCTUnwrap(Timecode(microseconds: 1_000_000)),
            end: XCTUnwrap(Timecode(microseconds: 6_000_000))
        ))
        let current = try XCTUnwrap(LyricWord(
            text: "Другая",
            start: XCTUnwrap(Timecode(microseconds: 3_000_000)),
            end: XCTUnwrap(Timecode(microseconds: 5_000_000))
        ))
        let cues = KaraokeExportTimeline.cues(
            from: [LyricLine(words: [previous]), LyricLine(words: [current])],
            duration: duration
        )
        XCTAssertEqual(cues.count, 3)
        XCTAssertEqual(cues.map(\.start.microseconds), [1_000_000, 3_000_000, 5_000_000])
        XCTAssertEqual(cues.map(\.end.microseconds), [3_000_000, 5_000_000, 6_000_000])
    }

    func testTwoLineExportHasUpcomingAndCurrentCues() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 9_000_000))
        let lyrics = LyricsDraftBuilder.build(text: "Первая\nВторая\nТретья", duration: duration)
        let cues = KaraokeDisplayTimeline.cues(from: lyrics, duration: duration)
        let current = cues.filter { $0.row == .current }
        let upcoming = cues.filter { $0.row == .upcoming }
        XCTAssertEqual(current.map(\.line.id), lyrics.map(\.id))
        XCTAssertEqual(upcoming.map(\.line.id), Array(lyrics.dropFirst()).map(\.id))
        XCTAssertEqual(upcoming.first?.start.microseconds, 0)
        XCTAssertEqual(upcoming.first?.end.microseconds, 3_000_000)
        XCTAssertEqual(current[1].start.microseconds, 3_000_000)
        XCTAssertEqual(current.map(\.slot), [.upper, .lower, .upper])
        XCTAssertEqual(upcoming.map(\.slot), [.lower, .upper])
    }

    func testTwoLineExportAndPreviewAgreeAtTransitions() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 10_000_000))
        let lyrics = LyricsDraftBuilder.build(text: "Раз два\nТри четыре\nПять", duration: duration)
        let cues = KaraokeDisplayTimeline.cues(from: lyrics, duration: duration)
        for seconds in [0.0, 1.5, 4.0, 5.0, 8.5, 9.9] {
            let time = try XCTUnwrap(Timecode(microseconds: Int64(seconds * 1_000_000)))
            let preview = KaraokeDisplayEngine.frame(at: time, lines: lyrics)
            let current = cues.first {
                $0.row == .current && $0.start <= time && time < $0.end
            }
            let next = cues.first {
                $0.row == .upcoming && $0.start <= time && time < $0.end
            }
            XCTAssertEqual(current?.line.id, preview.current?.lineID)
            XCTAssertEqual(next?.line.id, preview.upcoming?.lineID)
            if preview.current != nil {
                XCTAssertEqual(current?.slot, preview.currentSlot)
            }
            if preview.upcoming != nil {
                XCTAssertEqual(next?.slot, preview.upcomingSlot)
            }
        }
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
