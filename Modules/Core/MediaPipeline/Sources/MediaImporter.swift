import AVFoundation
import Foundation
import MelomanDomain

public enum MediaImportError: LocalizedError {
    case unsupportedFormat
    case missingMediaTracks
    case invalidDuration

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "Формат файла пока не поддерживается."
        case .missingMediaTracks:
            "В файле не найдены аудио- или видеодорожки."
        case .invalidDuration:
            "Не удалось определить длительность записи."
        }
    }
}

/// Probes source media without copying or modifying it.
/// File ownership and durable storage are managed by ProjectStore.
public struct MediaImporter: Sendable {
    public static let supportedExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aiff", "aif", "mp4", "m4v", "mov",
    ]

    public init() {}

    public func inspect(_ url: URL) async throws -> MediaAsset {
        guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw MediaImportError.unsupportedFormat
        }

        let asset = AVURLAsset(url: url)
        async let duration = asset.load(.duration)
        async let video = asset.loadTracks(withMediaType: .video)
        async let audio = asset.loadTracks(withMediaType: .audio)
        let (loadedDuration, videoTracks, audioTracks) = try await (duration, video, audio)

        guard !videoTracks.isEmpty || !audioTracks.isEmpty else {
            throw MediaImportError.missingMediaTracks
        }

        let seconds = loadedDuration.seconds
        guard seconds.isFinite, seconds > 0,
              seconds < Double(Int64.max) / 1_000_000,
              let timecode = Timecode(microseconds: Int64((seconds * 1_000_000).rounded()))
        else {
            throw MediaImportError.invalidDuration
        }

        return MediaAsset(
            name: url.lastPathComponent,
            fileExtension: url.pathExtension,
            kind: videoTracks.isEmpty ? .audio : .video,
            duration: timecode
        )
    }
}
