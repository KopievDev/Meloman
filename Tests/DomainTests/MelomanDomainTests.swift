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

    func testVisualOverlaysArePerMediaAndTimeBounded() throws {
        let first = UUID()
        let second = UUID()
        let start = try XCTUnwrap(Timecode(microseconds: 2_000_000))
        let end = try XCTUnwrap(Timecode(microseconds: 5_000_000))
        let overlay = try XCTUnwrap(VisualOverlay(
            mediaID: first, fileExtension: "GIF", start: start, end: end
        ))
        var project = MelomanProject(name: "Graphics")
        project.upsertOverlay(overlay)
        XCTAssertEqual(project.overlays(for: first).map(\.id), [overlay.id])
        XCTAssertTrue(project.overlays(for: second).isEmpty)
        XCTAssertTrue(overlay.isActive(at: start))
        XCTAssertFalse(overlay.isActive(at: end))
        XCTAssertEqual(overlay.packagedFilename, "\(overlay.id.uuidString).gif")

        let restored = try JSONDecoder().decode(MelomanProject.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(restored.overlays(for: first), [overlay])
        project.removeOverlay(overlay.id)
        XCTAssertTrue(project.overlays(for: first).isEmpty)
    }

    func testInvalidVisualOverlayValuesRejected() throws {
        let start = Timecode.zero
        let end = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        XCTAssertNil(VisualOverlay(mediaID: UUID(), fileExtension: "svg", start: start, end: end))
        XCTAssertNil(VisualOverlay(mediaID: UUID(), fileExtension: "png", start: end, end: start))
        XCTAssertNil(VisualOverlay(
            mediaID: UUID(), fileExtension: "png", start: start, end: end, width: 1.2
        ))
        XCTAssertNil(VisualOverlay(
            mediaID: UUID(), fileExtension: "png", start: start, end: end, centerX: .nan
        ))
    }

    func testK2PronunciationPersistsAndSharesEnglishWordIdentity() throws {
        let mediaID = UUID()
        let english = try XCTUnwrap(LyricWord(
            text: "look", start: .zero, end: XCTUnwrap(Timecode(microseconds: 800_000))
        ))
        var project = MelomanProject(name: "EN with RU hints")
        project.setKaraokeLines([LyricLine(words: [english])], for: mediaID)
        var track = KaraokePronunciationTrack(isEnabled: true)
        track.setText("лук", for: english.id)
        project.setKaraokePronunciation(track, for: mediaID)
        let decoded = try JSONDecoder().decode(
            MelomanProject.self, from: JSONEncoder().encode(project)
        )
        XCTAssertEqual(decoded.karaokePronunciation(for: mediaID), track)
        XCTAssertEqual(decoded.karaokePronunciation(for: mediaID).text(for: english.id), "лук")
        XCTAssertFalse(decoded.karaokePronunciation(for: UUID()).isEnabled)

        project.setKaraokeLines([], for: mediaID)
        XCTAssertTrue(project.karaokePronunciation(for: mediaID).words.isEmpty)
        XCTAssertTrue(project.karaokePronunciation(for: mediaID).isEnabled)
    }

    func testLegacyKaraokeDocumentsHaveNoPronunciation() throws {
        let mediaID = UUID()
        let original = KaraokeDocument(mediaID: mediaID)
        let encoded = try JSONEncoder().encode(original)
        let legacy = try JSONDecoder().decode(KaraokeDocument.self, from: encoded)
        XCTAssertNil(legacy.pronunciation)
    }

    func testWordPronunciationCanBeClearedWithoutTouchingEnglish() {
        let wordID = UUID()
        var track = KaraokePronunciationTrack(isEnabled: true)
        track.setText(" ю ", for: wordID)
        XCTAssertEqual(track.text(for: wordID), "ю")
        track.setText(" ", for: wordID)
        XCTAssertNil(track.text(for: wordID))
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
