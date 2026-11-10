import Foundation
import MelomanDomain
import ProjectStore
import XCTest

final class ProjectStoreTests: XCTestCase {
    func testPackageSurvivesSourceRemovalAndReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("song.mp3")
        let data = Data("placeholder sample media".utf8)
        try data.write(to: source)
        let asset = MediaAsset(name: "song.mp3", fileExtension: "mp3", kind: .audio, duration: .zero)
        let project = MelomanProject(name: "My Karaoke", media: [asset])
        let bundle = ProjectBundle(project: project, mediaURLs: [asset.id: source])
        let destination = directory.appendingPathComponent("Party.meloman")

        let stored = try ProjectStore().save(bundle, to: destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.mediaURLs[asset.id]?.path ?? ""))

        try FileManager.default.removeItem(at: source)
        let reopened = try ProjectStore().open(at: destination)
        XCTAssertEqual(reopened.project, project)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.mediaURLs[asset.id])), data)
    }

    func testSecondSaveReplacesPackageAndKeepsAssets() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("test.wav")
        try Data("audio source".utf8).write(to: source)
        let asset = MediaAsset(name: "test.wav", fileExtension: "wav", kind: .audio, duration: .zero)
        let destination = directory.appendingPathComponent("Demo.meloman")
        let first = ProjectBundle(
            project: MelomanProject(name: "First", media: [asset]),
            mediaURLs: [asset.id: source]
        )

        let saved = try ProjectStore().save(first, to: destination)
        var renamed = saved.project
        renamed.name = "Second"
        try ProjectStore().save(
            ProjectBundle(project: renamed, mediaURLs: saved.mediaURLs),
            to: destination
        )

        let reopened = try ProjectStore().open(at: destination)
        XCTAssertEqual(reopened.project.name, "Second")
        XCTAssertNotNil(reopened.mediaURLs[asset.id])
    }

    func testBackgroundIsPortableAndSurvivesReSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let audio = directory.appendingPathComponent("song.mp3")
        let image = directory.appendingPathComponent("cover.png")
        try Data("audio".utf8).write(to: audio)
        let pixels = Data("image payload".utf8)
        try pixels.write(to: image)
        let asset = MediaAsset(name: "song.mp3", fileExtension: "mp3", kind: .audio, duration: .zero)
        var project = MelomanProject(name: "With image", media: [asset])
        project.setBackgroundImage(MediaBackgroundImage(mediaID: asset.id, fileExtension: "png"), for: asset.id)
        let destination = directory.appendingPathComponent("Background.meloman")

        let saved = try ProjectStore().save(
            ProjectBundle(project: project, mediaURLs: [asset.id: audio], backgroundURLs: [asset.id: image]),
            to: destination
        )
        try FileManager.default.removeItem(at: image)
        var reopened = try ProjectStore().open(at: destination)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.backgroundURLs[asset.id])), pixels)
        XCTAssertEqual(reopened.project.backgroundImage(for: asset.id)?.fileExtension, "png")

        reopened = try ProjectStore().save(reopened, to: destination)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.backgroundURLs[asset.id])), pixels)
        XCTAssertEqual(saved.project, reopened.project)
    }

    func testMissingPackagedBackgroundIsReported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let audio = directory.appendingPathComponent("test.wav")
        let image = directory.appendingPathComponent("cover.jpg")
        try Data("audio".utf8).write(to: audio)
        try Data("image".utf8).write(to: image)
        let asset = MediaAsset(name: "test.wav", fileExtension: "wav", kind: .audio, duration: .zero)
        var project = MelomanProject(name: "Missing background", media: [asset])
        project.setBackgroundImage(MediaBackgroundImage(mediaID: asset.id, fileExtension: "jpg"), for: asset.id)
        let destination = directory.appendingPathComponent("Missing.meloman")

        let saved = try ProjectStore().save(
            ProjectBundle(project: project, mediaURLs: [asset.id: audio], backgroundURLs: [asset.id: image]),
            to: destination
        )
        try FileManager.default.removeItem(at: XCTUnwrap(saved.backgroundURLs[asset.id]))
        XCTAssertThrowsError(try ProjectStore().open(at: destination))
    }

    func testVideoBackgroundIsPortableAndSurvivesResave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let audio = directory.appendingPathComponent("track.wav")
        let video = directory.appendingPathComponent("visual.mov")
        let data = Data("sample background video bytes".utf8)
        try Data("audio".utf8).write(to: audio)
        try data.write(to: video)
        let media = MediaAsset(name: "track.wav", fileExtension: "wav", kind: .audio, duration: .zero)
        var project = MelomanProject(name: "Video Background", media: [media])
        project.setBackgroundVideo(MediaBackgroundVideo(mediaID: media.id, fileExtension: "mov"), for: media.id)
        let path = directory.appendingPathComponent("Video.meloman")
        var saved = try ProjectStore().save(
            ProjectBundle(project: project, mediaURLs: [media.id: audio], backgroundVideoURLs: [media.id: video]),
            to: path
        )
        try FileManager.default.removeItem(at: video)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(saved.backgroundVideoURLs[media.id])), data)

        saved = try ProjectStore().save(saved, to: path)
        let reopened = try ProjectStore().open(at: path)
        XCTAssertEqual(reopened.project.backgroundVideo(for: media.id)?.fileExtension, "mov")
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.backgroundVideoURLs[media.id])), data)
    }

    func testMissingVideoBackgroundFailsToOpen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let audio = directory.appendingPathComponent("song.mp3")
        let video = directory.appendingPathComponent("background.mp4")
        try Data("audio".utf8).write(to: audio)
        try Data("video".utf8).write(to: video)
        let media = MediaAsset(name: "song.mp3", fileExtension: "mp3", kind: .audio, duration: .zero)
        var project = MelomanProject(name: "Missing Video", media: [media])
        project.setBackgroundVideo(MediaBackgroundVideo(mediaID: media.id, fileExtension: "mp4"), for: media.id)
        let path = directory.appendingPathComponent("MissingVideo.meloman")
        let saved = try ProjectStore().save(
            ProjectBundle(project: project, mediaURLs: [media.id: audio], backgroundVideoURLs: [media.id: video]),
            to: path
        )
        try FileManager.default.removeItem(at: XCTUnwrap(saved.backgroundVideoURLs[media.id]))
        XCTAssertThrowsError(try ProjectStore().open(at: path))
    }

    func testGIFBackgroundIsStoredInsidePackage() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let audio = folder.appendingPathComponent("song.wav")
        let gif = folder.appendingPathComponent("animation.gif")
        try Data("music".utf8).write(to: audio)
        let bytes = Data("GIF89a example bytes".utf8)
        try bytes.write(to: gif)
        let asset = MediaAsset(name: "song.wav", fileExtension: "wav", kind: .audio, duration: .zero)
        var project = MelomanProject(name: "GIF Background", media: [asset])
        project.setBackgroundImage(MediaBackgroundImage(mediaID: asset.id, fileExtension: "gif"), for: asset.id)

        let path = folder.appendingPathComponent("GIF.meloman")
        let saved = try ProjectStore().save(
            ProjectBundle(project: project, mediaURLs: [asset.id: audio], backgroundURLs: [asset.id: gif]),
            to: path
        )
        try FileManager.default.removeItem(at: gif)
        let reopened = try ProjectStore().open(at: path)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(saved.backgroundURLs[asset.id])), bytes)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(reopened.backgroundURLs[asset.id])), bytes)
        XCTAssertEqual(reopened.project.backgroundImage(for: asset.id)?.fileExtension, "gif")
    }

    func testMultipleVisualOverlaysSurvivePortableSaveAndResave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let audio = directory.appendingPathComponent("song.wav")
        let png = directory.appendingPathComponent("logo.png")
        let gif = directory.appendingPathComponent("sparkle.gif")
        try Data("audio".utf8).write(to: audio)
        try Data("logo".utf8).write(to: png)
        try Data("animated".utf8).write(to: gif)

        let media = MediaAsset(name: "song.wav", fileExtension: "wav", kind: .audio, duration: .zero)
        let end = try XCTUnwrap(Timecode(microseconds: 5_000_000))
        let first = try XCTUnwrap(VisualOverlay(
            mediaID: media.id, fileExtension: "png", start: .zero, end: end
        ))
        let second = try XCTUnwrap(VisualOverlay(
            mediaID: media.id, fileExtension: "gif", start: .zero, end: end
        ))
        var project = MelomanProject(name: "Overlay Package", media: [media])
        project.upsertOverlay(first)
        project.upsertOverlay(second)
        let path = directory.appendingPathComponent("Overlays.meloman")
        var saved = try ProjectStore().save(
            ProjectBundle(
                project: project,
                mediaURLs: [media.id: audio],
                overlayURLs: [first.id: png, second.id: gif]
            ),
            to: path
        )
        try FileManager.default.removeItem(at: png)
        try FileManager.default.removeItem(at: gif)
        saved = try ProjectStore().save(saved, to: path)
        let loaded = try ProjectStore().open(at: path)
        XCTAssertEqual(loaded.project.overlays(for: media.id).count, 2)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(loaded.overlayURLs[first.id])), Data("logo".utf8))
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(loaded.overlayURLs[second.id])), Data("animated".utf8))
    }

    func testK2PronunciationSurvivesPortablePackageReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("english.mp3")
        try Data("audio".utf8).write(to: source)
        let media = MediaAsset(name: "english.mp3", fileExtension: "mp3", kind: .audio, duration: .zero)
        let word = try XCTUnwrap(LyricWord(
            text: "Look,", start: .zero,
            end: XCTUnwrap(Timecode(microseconds: 900_000))
        ))
        var project = MelomanProject(name: "EN + RU", media: [media])
        project.setKaraokeLines([LyricLine(words: [word])], for: media.id)
        var k2 = KaraokePronunciationTrack(isEnabled: true)
        k2.setText("Лук,", for: word.id)
        project.setKaraokePronunciation(k2, for: media.id)

        let destination = directory.appendingPathComponent("EN-RU.meloman")
        let saved = try ProjectStore().save(
            ProjectBundle(project: project, mediaURLs: [media.id: source]),
            to: destination
        )
        try FileManager.default.removeItem(at: source)
        _ = try ProjectStore().save(saved, to: destination)
        let reopened = try ProjectStore().open(at: destination)
        XCTAssertEqual(reopened.project.karaokePronunciation(for: media.id), k2)
        XCTAssertEqual(reopened.project.karaokeLines(for: media.id)[0].words[0].id, word.id)
    }

    func testProjectMustUseMelomanExtension() {
        let invalid = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-package.zip")
        XCTAssertThrowsError(try ProjectStore().open(at: invalid))
    }
}
