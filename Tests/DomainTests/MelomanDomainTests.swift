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

    func testDraggingWordKeepsIdentityAndPronunciationTiming() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 10_000_000))
        let first = try XCTUnwrap(LyricWord(
            text: "Look", start: .zero,
            end: XCTUnwrap(Timecode(microseconds: 500_000)),
            alignmentConfidence: 0.45
        ))
        let second = try XCTUnwrap(LyricWord(
            text: "you", start: XCTUnwrap(Timecode(microseconds: 800_000)),
            end: XCTUnwrap(Timecode(microseconds: 1_200_000))
        ))
        let original = [LyricLine(words: [first, second])]
        let modified = try XCTUnwrap(LyricTimingEditor.applying(
            .moveWord, to: second.id, in: original,
            deltaMicroseconds: 500_000, mediaDuration: duration
        ))
        XCTAssertEqual(modified[0].words[1].start.microseconds, 1_300_000)
        XCTAssertEqual(modified[0].words[1].end.microseconds, 1_700_000)
        XCTAssertEqual(modified[0].words[1].id, second.id)
        XCTAssertEqual(modified[0].words[0], first)
        XCTAssertEqual(original[0].words[1], second)
    }

    func testTrimmingWordClampsToMinimumDurationAndTrackBounds() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 1_500_000))
        let word = try XCTUnwrap(LyricWord(
            text: "песня", start: XCTUnwrap(Timecode(microseconds: 300_000)),
            end: XCTUnwrap(Timecode(microseconds: 800_000))
        ))
        let lines = [LyricLine(words: [word])]
        let trimmedStart = try XCTUnwrap(LyricTimingEditor.applying(
            .trimStart, to: word.id, in: lines,
            deltaMicroseconds: 3_000_000, mediaDuration: duration
        ))
        XCTAssertEqual(trimmedStart[0].words[0].start.microseconds, 750_000)
        XCTAssertEqual(trimmedStart[0].words[0].end.microseconds, 800_000)

        let trimmedEnd = try XCTUnwrap(LyricTimingEditor.applying(
            .trimEnd, to: word.id, in: lines,
            deltaMicroseconds: -3_000_000, mediaDuration: duration
        ))
        XCTAssertEqual(trimmedEnd[0].words[0].start.microseconds, 300_000)
        XCTAssertEqual(trimmedEnd[0].words[0].end.microseconds, 350_000)

        let bounded = try XCTUnwrap(LyricTimingEditor.applying(
            .moveWord, to: word.id, in: lines,
            deltaMicroseconds: 10_000_000, mediaDuration: duration
        ))
        XCTAssertEqual(bounded[0].words[0].end.microseconds, duration.microseconds)
    }

    func testOptionDraggingMovesWholeLyricLineWithoutChangingGaps() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 2_000_000))
        let first = try XCTUnwrap(LyricWord(
            text: "Сорвал", start: XCTUnwrap(Timecode(microseconds: 200_000)),
            end: XCTUnwrap(Timecode(microseconds: 450_000))
        ))
        let second = try XCTUnwrap(LyricWord(
            text: "ветер", start: XCTUnwrap(Timecode(microseconds: 700_000)),
            end: XCTUnwrap(Timecode(microseconds: 900_000))
        ))
        let lines = [LyricLine(words: [first, second])]
        let moved = try XCTUnwrap(LyricTimingEditor.applying(
            .moveLine, to: first.id, in: lines,
            deltaMicroseconds: -5_000_000, mediaDuration: duration
        ))
        XCTAssertEqual(moved[0].words[0].start.microseconds, 0)
        XCTAssertEqual(moved[0].words[1].start.microseconds, 500_000)
        XCTAssertEqual(moved[0].words[1].end.microseconds, 700_000)
    }

    func testTimingSnapUsesAbsoluteBoundaryAndRejectsUnknownWord() throws {
        let anchor = try XCTUnwrap(Timecode(microseconds: 123_000))
        XCTAssertEqual(LyricTimingEditor.snappedDelta(
            from: anchor, proposedDelta: 60000
        ), 77000)
        XCTAssertEqual(LyricTimingEditor.snappedDelta(
            from: anchor, proposedDelta: 60000, intervalMicroseconds: 0
        ), 60000)
        XCTAssertNil(LyricTimingEditor.applying(
            .moveWord, to: UUID(), in: [], deltaMicroseconds: 50000,
            mediaDuration: try XCTUnwrap(Timecode(microseconds: 5_000_000))
        ))
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
