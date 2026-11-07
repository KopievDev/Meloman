import Foundation
import LocalAI
import XCTest

final class VocalStemCacheTests: XCTestCase {
    func testSourceContentsProduceStableKeys() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = root.appendingPathComponent("original.mp3")
        let renamed = root.appendingPathComponent("renamed.mp3")
        try Data("song payload".utf8).write(to: first)
        try FileManager.default.copyItem(at: first, to: renamed)

        let hash1 = try await VocalStemCache.key(for: first)
        let hash2 = try await VocalStemCache.key(for: renamed)
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash1.count, 64)

        try Data("changed payload".utf8).write(to: renamed)
        XCTAssertNotEqual(try await VocalStemCache.key(for: renamed), hash1)
    }

    func testAbsentStemIsNeverAcceptedAsCacheHit() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-present-\(UUID().uuidString).wav")
        XCTAssertFalse(VocalStemCache.isValid(missing))
    }
}
