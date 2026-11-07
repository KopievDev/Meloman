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

    func testProjectMustUseMelomanExtension() {
        let invalid = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-package.zip")
        XCTAssertThrowsError(try ProjectStore().open(at: invalid))
    }
}
