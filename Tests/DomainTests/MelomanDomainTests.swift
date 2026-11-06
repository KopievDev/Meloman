import Foundation
import MelomanDomain
import XCTest

final class MelomanDomainTests: XCTestCase {
    func testTimecodeRejectsNegativeMicroseconds() {
        XCTAssertNil(Timecode(microseconds: -1))
        XCTAssertEqual(Timecode.zero.microseconds, 0)
    }

    func testTimecodeRejectsInvalidDecodedValue() {
        let payload = Data("-15".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Timecode.self, from: payload))
    }

    func testWordsRequireDurationAndText() throws {
        let start = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        let end = try XCTUnwrap(Timecode(microseconds: 2_000_000))

        XCTAssertNil(LyricWord(text: "", start: start, end: end))
        XCTAssertNil(LyricWord(text: "музыка", start: start, end: start))
        XCTAssertNotNil(LyricWord(text: "музыка", start: start, end: end))
    }

    func testOriginalAudioIsDefaultAndVocalRemovalCanBeEnabled() {
        var project = MelomanProject(name: "Тестовый проект")
        XCTAssertFalse(project.vocalRemoval.isEnabled)

        project.vocalRemoval.isEnabled = true
        XCTAssertTrue(project.vocalRemoval.isEnabled)
    }

    func testProjectJSONRoundTripPreservesLyricsAndTracks() throws {
        let start = try XCTUnwrap(Timecode(microseconds: 100_000))
        let end = try XCTUnwrap(Timecode(microseconds: 750_000))
        let word = try XCTUnwrap(LyricWord(text: "Привет", start: start, end: end))
        let line = LyricLine(words: [word])
        let track = TimelineTrack(kind: .karaoke)

        let original = MelomanProject(
            name: "Караоке",
            createdAt: Date(timeIntervalSince1970: 0),
            tracks: [track],
            lyrics: [line],
            vocalRemoval: .init(isEnabled: true)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MelomanProject.self, from: encoded)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.lyrics.first?.words.first?.text, "Привет")
        XCTAssertTrue(decoded.vocalRemoval.isEnabled)
    }
}
