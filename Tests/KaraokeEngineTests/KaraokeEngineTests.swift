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

    func testMultiMediaKaraokeDocumentsStayIndependent() throws {
        let firstID = UUID()
        let secondID = UUID()
        let duration = try XCTUnwrap(Timecode(microseconds: 3_000_000))
        let a = LyricsDraftBuilder.build(text: "А Б", duration: duration)
        let b = LyricsDraftBuilder.build(text: "В Г", duration: duration)

        var project = MelomanProject(name: "Музыкальный вечер")
        project.setKaraokeLines(a, for: firstID)
        project.setKaraokeLines(b, for: secondID)

        XCTAssertEqual(project.karaokeLines(for: firstID), a)
        XCTAssertEqual(project.karaokeLines(for: secondID), b)
        let decoded = try JSONDecoder().decode(
            MelomanProject.self,
            from: JSONEncoder().encode(project)
        )
        XCTAssertEqual(decoded.karaokeLines(for: secondID), b)
    }
}
