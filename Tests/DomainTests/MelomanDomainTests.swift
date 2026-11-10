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

    func testImageBackgroundIsPerMediaAndCanBeRemoved() throws {
        let first = UUID()
        let second = UUID()
        var project = MelomanProject(name: "Тест")
        let image = MediaBackgroundImage(mediaID: first, fileExtension: "PNG")
        project.setBackgroundImage(image, for: first)

        XCTAssertEqual(project.backgroundImage(for: first)?.packagedFilename, "\(first.uuidString).png")
        XCTAssertNil(project.backgroundImage(for: second))
        let decoded = try JSONDecoder().decode(MelomanProject.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(decoded.backgroundImage(for: first), project.backgroundImage(for: first))

        project.setBackgroundImage(nil, for: first)
        XCTAssertNil(project.backgroundImage(for: first))
    }

    func testVideoBackgroundIsPerTrackAndOptional() throws {
        let id = UUID()
        let another = UUID()
        var project = MelomanProject(name: "Видео")
        let video = MediaBackgroundVideo(mediaID: id, fileExtension: "MOV")
        project.setBackgroundVideo(video, for: id)

        XCTAssertEqual(project.backgroundVideo(for: id)?.packagedFilename, "\(id.uuidString).mov")
        XCTAssertNil(project.backgroundVideo(for: another))

        let encoded = try JSONEncoder().encode(project)
        let restored = try JSONDecoder().decode(MelomanProject.self, from: encoded)
        XCTAssertEqual(restored.backgroundVideo(for: id), video)

        project.setBackgroundVideo(nil, for: id)
        XCTAssertNil(project.backgroundVideo(for: id))
    }

    func testLegacyProjectWithoutBackgroundImagesDecodes() throws {
        let project = MelomanProject(name: "Старый проект")
        let data = try JSONEncoder().encode(project)
        let restored = try JSONDecoder().decode(MelomanProject.self, from: data)
        XCTAssertNil(restored.backgroundImages)
        XCTAssertNil(restored.backgroundVideos)
    }

    func testGIFPlaybackTimingRespectsFrameDelayAndLoops() {
        let timing = GIFPlaybackTiming(frameDurations: [0.1, 0.25, 0.05])
        XCTAssertEqual(timing.totalDuration, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(timing.frameIndex(at: 0), 0)
        XCTAssertEqual(timing.frameIndex(at: 0.2), 1)
        XCTAssertEqual(timing.frameIndex(at: 0.38), 2)
        XCTAssertEqual(timing.frameIndex(at: 0.41), 0)
        XCTAssertEqual(timing.frameIndex(at: 0.6), 1)
        XCTAssertNil(timing.frameIndex(at: .infinity))
        XCTAssertNil(GIFPlaybackTiming(frameDurations: []).frameIndex(at: 0))
    }

    func testInvalidGIFDelaysGetSafeFallbacks() {
        let timing = GIFPlaybackTiming(frameDurations: [0, -1, .nan, 0.04])
        XCTAssertEqual(timing.durations, [0.1, 0.1, 0.1, 0.04])
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
