import AVFoundation
import Foundation
import MelomanDomain

public enum TranscriptionAudioError: LocalizedError {
    case noExportSession

    public var errorDescription: String? {
        "Не удалось извлечь аудиодорожку из видео для распознавания."
    }
}

/// WhisperKit reads files via AVAudioFile. Videos must be converted to an
/// audio-only temporary file first. Never changes or overwrites the source.
public struct TranscriptionAudioPreparer: Sendable {
    public init() {}

    public func prepare(source: URL, kind: MediaKind) async throws -> URL {
        guard kind == .video else { return source }
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionAudioError.noExportSession
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("meloman-asr-\(UUID().uuidString).m4a")
        try await session.export(to: output, as: .m4a)
        return output
    }
}
