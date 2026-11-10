import Foundation
import MelomanDomain
import XCTest

final class KaraokeStyleTests: XCTestCase {
    func testStylesRoundTripWithoutChangingLyrics() throws {
        let songID = UUID()
        let otherID = UUID()
        var project = MelomanProject(name: "Стили")
        let times = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        let word = try XCTUnwrap(LyricWord(text: "Привет!", start: .zero, end: times))
        project.setKaraokeLines([LyricLine(words: [word])], for: songID)

        let style = KaraokeStyle(
            font: .avenirDemiBold,
            fontSize: 70,
            textColor: KaraokeRGB(red: 10, green: 20, blue: 30),
            highlightColor: KaraokeRGB(red: 232, green: 120, blue: 7),
            verticalPosition: 0.65
        )
        project.setKaraokeStyle(style, for: songID)
        let data = try JSONEncoder().encode(project)
        let reopened = try JSONDecoder().decode(MelomanProject.self, from: data)

        XCTAssertEqual(reopened.karaokeStyle(for: songID), style)
        XCTAssertEqual(reopened.karaokeStyle(for: otherID), KaraokeStyle())
        XCTAssertEqual(reopened.karaokeLines(for: songID)[0].words[0].text, "Привет!")
    }

    func testOldDocumentWithoutStyleGetsDefault() throws {
        let mediaID = UUID()
        let json = "{\"mediaID\":\"\(mediaID.uuidString)\",\"lines\":[]}"
        let document = try JSONDecoder().decode(KaraokeDocument.self, from: Data(json.utf8))
        XCTAssertNil(document.style)
        XCTAssertEqual(document.mediaID, mediaID)

        var project = MelomanProject(name: "Старый")
        project.karaokeDocuments = [document]
        XCTAssertEqual(project.karaokeStyle(for: mediaID), .init())
    }

    func testInvalidGeometryIsClampedBeforeRenderingAndSaving() {
        let invalid = KaraokeStyle(fontSize: .infinity, verticalPosition: -.infinity)
        let safe = invalid.sanitized()
        XCTAssertEqual(safe.fontSize, 56)
        XCTAssertEqual(safe.verticalPosition, 0.18)

        let oversized = KaraokeStyle(fontSize: 5000, verticalPosition: 10).sanitized()
        XCTAssertEqual(oversized.fontSize, 112)
        XCTAssertEqual(oversized.verticalPosition, 0.85)
    }
}
