import Foundation
import KaraokeEngine
import MelomanDomain
import XCTest

final class KaraokeEngineTests: XCTestCase {
    func testProgressFillsInsideWord() throws {
        let start = try XCTUnwrap(Timecode(microseconds: 2_000_000))
        let end = try XCTUnwrap(Timecode(microseconds: 4_000_000))
        let word = try XCTUnwrap(LyricWord(text: "Привет", start: start, end: end))

        XCTAssertEqual(KaraokeEngine.progress(of: word, at: .zero), 0)
        XCTAssertEqual(KaraokeEngine.progress(of: word, at: start), 0)
        let halfway = try XCTUnwrap(Timecode(microseconds: 3_000_000))
        XCTAssertEqual(
            KaraokeEngine.progress(of: word, at: halfway),
            0.5,
            accuracy: 0.00001
        )
        XCTAssertEqual(KaraokeEngine.progress(of: word, at: end), 1)
    }

    func testPlaybackAndSeekAreDeterministic() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 6_000_000))
        let lines = LyricsDraftBuilder.build(text: "Один два\nтри", duration: duration)
        let half = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        let first = try XCTUnwrap(KaraokeEngine.frame(at: half, lines: lines))
        XCTAssertEqual(first.words.map(\.text), ["Один", "два"])
        XCTAssertEqual(first.words[0].progress, 0.5, accuracy: 0.00001)

        XCTAssertEqual(KaraokeEngine.frame(at: half, lines: lines), first)
        XCTAssertNil(KaraokeEngine.frame(at: .zero, lines: []))
        XCTAssertNil(KaraokeEngine.frame(at: duration, lines: lines))
    }

    func testHiddenWordsPreserveTiming() throws {
        let source = try XCTUnwrap(Timecode(microseconds: 2_000_000))
        let lines = LyricsDraftBuilder.build(text: "Зима лето", duration: source)
        var hidden = lines
        hidden[0].words[1].isHidden = true

        let time = try XCTUnwrap(Timecode(microseconds: 1_500_000))
        let frame = try XCTUnwrap(KaraokeEngine.frame(at: time, lines: hidden))
        XCTAssertTrue(frame.words[1].isHidden)
        XCTAssertEqual(frame.words[1].progress, 0.5, accuracy: 0.00001)
    }

    func testDraftPreservesLinesAndCyrillicAndMilliseconds() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 7_000_003))
        let lines = LyricsDraftBuilder.build(text: "Привет, мир!\n\nЁжик здесь", duration: duration)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].words.map(\.text), ["Привет,", "мир!"])
        XCTAssertEqual(lines[1].words.map(\.text), ["Ёжик", "здесь"])
        XCTAssertEqual(lines[0].words.first?.start, .zero)
        XCTAssertEqual(lines[1].words.last?.end, duration)
    }

    func testLineStillAppearsWhenAlignedWordTimesAreOutOfOrder() throws {
        func word(_ text: String, _ begin: Int64, _ finish: Int64) throws -> LyricWord {
            try XCTUnwrap(LyricWord(
                text: text,
                start: XCTUnwrap(Timecode(microseconds: begin)),
                end: XCTUnwrap(Timecode(microseconds: finish))
            ))
        }
        let line = try LyricLine(words: [
            word("Ночь", 30_000_000, 30_300_000),
            word("и", 28_000_000, 28_200_000),
            word("огни", 29_575_000, 30_056_000),
        ])
        let earlier = try XCTUnwrap(Timecode(microseconds: 29_700_000))
        let later = try XCTUnwrap(Timecode(microseconds: 30_100_000))
        XCTAssertEqual(KaraokeEngine.frame(at: earlier, lines: [line])?.lineID, line.id)
        XCTAssertEqual(KaraokeEngine.frame(at: later, lines: [line])?.lineID, line.id)
    }

    func testOverlappingLinesPreferTheOneWithTheLatestActiveWord() throws {
        func word(_ text: String, _ from: Int64, _ until: Int64) throws -> LyricWord {
            try XCTUnwrap(LyricWord(
                text: text,
                start: XCTUnwrap(Timecode(microseconds: from)),
                end: XCTUnwrap(Timecode(microseconds: until))
            ))
        }
        let previous = try LyricLine(words: [
            word("Раньше", 24_000_000, 34_000_000),
        ])
        let current = try LyricLine(words: [
            word("Сейчас", 29_575_000, 30_056_000),
        ])
        let time = try XCTUnwrap(Timecode(microseconds: 29_700_000))
        XCTAssertEqual(KaraokeEngine.frame(at: time, lines: [previous, current])?.lineID, current.id)
    }

    func testTwoLinesShowUpcomingTextBeforeItsFirstWord() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 12_000_000))
        let lyrics = LyricsDraftBuilder.build(text: "Сейчас поём\nСледующая строка\nФинал", duration: duration)
        let point = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        let display = KaraokeDisplayEngine.frame(at: point, lines: lyrics)

        XCTAssertEqual(display.current?.words.map(\.text), ["Сейчас", "поём"])
        XCTAssertEqual(display.upcoming?.words.map(\.text), ["Следующая", "строка"])
        XCTAssertTrue(display.upcoming?.words.allSatisfy { $0.progress == 0 } == true)
    }

    func testNextLineMovesToTopWhenSingingStarts() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 9_000_000))
        let lyrics = LyricsDraftBuilder.build(text: "Первая\nВторая\nТретья", duration: duration)
        let before = try XCTUnwrap(Timecode(microseconds: 2_900_000))
        let after = try XCTUnwrap(Timecode(microseconds: 3_100_000))
        let prepared = KaraokeDisplayEngine.frame(at: before, lines: lyrics)
        let changed = KaraokeDisplayEngine.frame(at: after, lines: lyrics)

        XCTAssertEqual(prepared.current?.lineID, lyrics[0].id)
        XCTAssertEqual(prepared.upcoming?.lineID, lyrics[1].id)
        XCTAssertEqual(changed.current?.lineID, lyrics[1].id)
        XCTAssertEqual(changed.upcoming?.lineID, lyrics[2].id)
        XCTAssertTrue((changed.current?.words.first?.progress ?? 0) > 0)
    }

    func testTwoLineSelectionSurvivesNonMonotonicAITimes() throws {
        func word(_ text: String, _ start: Int64, _ end: Int64) throws -> LyricWord {
            try XCTUnwrap(LyricWord(
                text: text,
                start: XCTUnwrap(Timecode(microseconds: start)),
                end: XCTUnwrap(Timecode(microseconds: end))
            ))
        }
        let first = try LyricLine(words: [
            word("Ночь", 2_000_000, 2_200_000),
            word("близко", 1_500_000, 2_500_000),
        ])
        let second = try LyricLine(words: [word("Утро", 3_000_000, 4_000_000)])
        let now = try XCTUnwrap(Timecode(microseconds: 1_800_000))
        let display = KaraokeDisplayEngine.frame(at: now, lines: [first, second])
        XCTAssertEqual(display.current?.lineID, first.id)
        XCTAssertEqual(display.upcoming?.lineID, second.id)
    }

    func testEnglishRussianPhoneticDraftMatchesExample() {
        let source = ["Look,", "if", "you", "had"]
        XCTAssertEqual(source.map(EnglishToRussianPronunciation.draft), ["Лук,", "иф", "ю", "хад"])
        XCTAssertEqual(EnglishToRussianPronunciation.draft("opportunity"), "оппортюнити")
    }

    func testDraftFillsMissingWordsWithoutOverwritingCorrections() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 4000000))
        let lyrics = LyricsDraftBuilder.build(text: "Look, if you had", duration: duration)
        let words = lyrics.flatMap(\.words)
        var track = KaraokePronunciationTrack(isEnabled: true)
        track.setText("Лук, (мой вариант)", for: words[0].id)
        let result = EnglishToRussianPronunciation.fillMissing(track: track, lines: lyrics)
        XCTAssertEqual(result.text(for: words[0].id), "Лук, (мой вариант)")
        XCTAssertEqual(result.text(for: words[1].id), "иф")
        XCTAssertEqual(result.text(for: words[2].id), "ю")
        XCTAssertEqual(result.text(for: words[3].id), "хад")
        XCTAssertFalse(result.words.contains(where: { $0.text.isEmpty }))
    }

    func testMultiMediaKaraokeDocumentsStayIndependent() throws {
        let firstID = UUID()
        let secondID = UUID()
        let duration = try XCTUnwrap(Timecode(microseconds: 3_000_000))
        let firstLyrics = LyricsDraftBuilder.build(text: "А Б", duration: duration)
        let secondLyrics = LyricsDraftBuilder.build(text: "В Г", duration: duration)

        var project = MelomanProject(name: "Музыкальный вечер")
        project.setKaraokeLines(firstLyrics, for: firstID)
        project.setKaraokeLines(secondLyrics, for: secondID)

        XCTAssertEqual(project.karaokeLines(for: firstID), firstLyrics)
        XCTAssertEqual(project.karaokeLines(for: secondID), secondLyrics)
        let decoded = try JSONDecoder().decode(
            MelomanProject.self,
            from: JSONEncoder().encode(project)
        )
        XCTAssertEqual(decoded.karaokeLines(for: secondID), secondLyrics)
    }
}
