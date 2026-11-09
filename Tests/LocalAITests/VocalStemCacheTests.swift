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
        let changedHash = try await VocalStemCache.key(for: renamed)
        XCTAssertNotEqual(changedHash, hash1)
    }

    func testDifferentEngineRevisionsCannotShareStems() throws {
        let digest = String(repeating: "a", count: 64)
        let spleeter = try VocalStemCache.directory(for: digest)
        let mlx = try VocalStemCache.directory(for: digest, revision: MLXRoFormerSeparator.modelRevision)
        XCTAssertNotEqual(spleeter, mlx)
        XCTAssertTrue(spleeter.path.contains("spleeter2-coreml-0.2.0"))
        XCTAssertTrue(mlx.path.contains("mlx-roformer-zfturbo-v1-0.1.20"))
    }

    func testRoFormerProfilesHaveSeparateModelAndCacheRevisions() throws {
        let lightweight = MLXRoFormerModel.zfTurbo
        let quality = MLXRoFormerModel.bsRoFormer

        XCTAssertEqual(lightweight.modelFileName, "mel-roformer-zfturbo-vocals-v1-mlx")
        XCTAssertEqual(quality.modelFileName, "model_bs_roformer_ep_317_sdr_12.9755.ckpt")
        XCTAssertNotEqual(lightweight.cacheRevision, quality.cacheRevision)

        let digest = String(repeating: "b", count: 64)
        let path1 = try VocalStemCache.directory(for: digest, revision: lightweight.cacheRevision)
        let path2 = try VocalStemCache.directory(for: digest, revision: quality.cacheRevision)
        XCTAssertNotEqual(path1, path2)
    }

    func testAbsentStemIsNeverAcceptedAsCacheHit() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-present-\(UUID().uuidString).wav")
        XCTAssertFalse(VocalStemCache.isValid(missing))
    }
}
