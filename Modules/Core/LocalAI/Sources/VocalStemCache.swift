import CryptoKit
import Foundation

/// Cache is keyed by the entire original file contents and the pinned model revision.
/// This survives changing the project path and prevents stale stems after a file edit.
public enum VocalStemCache {
    public static let modelRevision = "spleeter2-coreml-0.2.0"

    public static func key(for url: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let stream = try FileHandle(forReadingFrom: url)
            defer { try? stream.close() }
            var digest = SHA256()
            while let data = try stream.read(upToCount: 1_048_576), !data.isEmpty {
                try Task.checkCancellation()
                digest.update(data: data)
            }
            return digest.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }

    public static func directory(for key: String) throws -> URL {
        guard key.count == 64, key.allSatisfy({ $0.isHexDigit }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root
            .appendingPathComponent("Meloman/Derived/Stems", isDirectory: true)
            .appendingPathComponent(modelRevision, isDirectory: true)
            .appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func isValid(_ url: URL) -> Bool {
        guard let metadata = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = metadata[.size] as? NSNumber
        else { return false }
        return size.int64Value > 44
    }
}
