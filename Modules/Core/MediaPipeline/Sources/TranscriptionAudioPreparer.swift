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

    @MainActor
    public func prepare(
        source: URL,
        kind: MediaKind,
        onProgress: @MainActor @escaping (Double?) -> Void
    ) async throws -> URL {
        guard kind == .video else { return source }
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionAudioError.noExportSession
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("meloman-asr-\(UUID().uuidString).m4a")
        let monitor = Task { @MainActor in
            for await state in session.states(updateInterval: 0.25) {
                guard !Task.isCancelled else { return }
                switch state {
                case let .exporting(progress):
                    onProgress(progress.totalUnitCount > 0 ? progress.fractionCompleted : nil)
                case .pending, .waiting:
                    onProgress(nil)
                @unknown default:
                    break
                }
            }
        }
        defer { monitor.cancel() }

        do {
            try await session.export(to: output, as: .m4a)
            onProgress(1)
            return output
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }
}
