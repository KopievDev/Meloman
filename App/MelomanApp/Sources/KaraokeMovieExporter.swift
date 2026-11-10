@preconcurrency import AVFoundation
import Foundation
import MelomanDomain

enum KaraokeVideoExportError: LocalizedError {
    case noVideo
    case noAudio
    case cannotCreateTrack
    case unavailableExportSession
    case unsupportedMP4
    case invalidVideoSize
    case invalidDuration
    case invalidBackgroundVideo

    var errorDescription: String? {
        switch self {
        case .noVideo: "В источнике не найдена видеодорожка."
        case .noAudio: "Не найдена аудиодорожка для экспорта."
        case .cannotCreateTrack: "Не удалось создать дорожку видео или аудио."
        case .unavailableExportSession: "Не удалось запустить экспорт видео."
        case .unsupportedMP4: "На этом Mac экспорт в MP4 недоступен."
        case .invalidVideoSize: "У видео некорректное разрешение."
        case .invalidDuration: "У исходного файла некорректная длительность."
        case .invalidBackgroundVideo: "Видеофон должен содержать видео длительностью не менее 0,5 секунды."
        }
    }
}

struct KaraokeMovieSources {
    let instrumental: URL?
    let backgroundImage: URL?
    let backgroundVideo: URL?
}

private struct MovieTrackLayout {
    let size: CGSize
    let transform: CGAffineTransform
}

/// Native offline rendering. Existing source assets are never overwritten.
/// Videos preserve source footage; audio-only imports can use an image or a silent looping video background.
@MainActor
final class KaraokeMovieExporter {
    var onProgress: ((String, String, Double?) -> Void)?

    func export(
        source: URL,
        media: MediaAsset,
        karaoke: KaraokeDocument,
        sources: KaraokeMovieSources,
        to destination: URL
    ) async throws {
        let seconds = Double(media.duration.microseconds) / 1_000_000
        guard seconds.isFinite, seconds > 0 else { throw KaraokeVideoExportError.invalidDuration }
        let mediaDuration = CMTime(value: media.duration.microseconds, timescale: 1_000_000)
        let working = FileManager.default.temporaryDirectory.appendingPathComponent(
            "meloman-export-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: working) }

        let loopedVideo = media.kind == .audio ? sources.backgroundVideo : nil
        let videoURL: URL
        if let loopedVideo {
            onProgress?("Подготовка видео", "Видеофон повторяется до конца песни", nil)
            videoURL = loopedVideo
        } else if media.kind == .audio {
            onProgress?(
                "Подготовка видео",
                sources.backgroundImage == nil ? "Создание чёрного фона" : "Подготовка изображения фона",
                nil
            )
            videoURL = try await KaraokeBackgroundMovie.make(
                duration: mediaDuration,
                at: working.appendingPathComponent("background.mov"),
                imageURL: sources.backgroundImage
            )
        } else {
            videoURL = source
        }

        onProgress?("Подготовка экспорта", "Сборка видео, звука и текста", nil)
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)
        let layout: MovieTrackLayout
        if loopedVideo != nil {
            layout = try await insertLoopedBackgroundVideo(
                from: videoAsset,
                into: composition,
                duration: mediaDuration
            )
        } else {
            layout = try await insertVideo(
                from: videoAsset,
                into: composition,
                duration: mediaDuration
            )
        }
        try await insertAudio(
            from: AVURLAsset(url: sources.instrumental ?? source),
            into: composition,
            duration: mediaDuration
        )
        let videoComposition = makeVideoComposition(
            composition: composition,
            layout: layout,
            duration: mediaDuration,
            karaoke: karaoke
        )
        try await exportComposition(
            composition,
            videoComposition: videoComposition,
            duration: mediaDuration,
            to: destination
        )
    }

    private func insertVideo(
        from asset: AVURLAsset,
        into composition: AVMutableComposition,
        duration: CMTime
    ) async throws -> MovieTrackLayout {
        guard let source = try await asset.loadTracks(withMediaType: .video).first else {
            throw KaraokeVideoExportError.noVideo
        }
        guard let target = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw KaraokeVideoExportError.cannotCreateTrack }

        let sourceDuration = try await asset.load(.duration)
        let clipDuration = CMTimeMinimum(sourceDuration, duration)
        try target.insertTimeRange(
            CMTimeRange(start: .zero, duration: clipDuration),
            of: source,
            at: .zero
        )
        target.preferredTransform = .identity
        return try await videoLayout(for: source)
    }


    private func insertLoopedBackgroundVideo(
        from asset: AVURLAsset,
        into composition: AVMutableComposition,
        duration: CMTime
    ) async throws -> MovieTrackLayout {
        guard let source = try await asset.loadTracks(withMediaType: .video).first else {
            throw KaraokeVideoExportError.invalidBackgroundVideo
        }
        let range = try await source.load(.timeRange)
        let available = range.duration
        guard available.isNumeric, available.seconds.isFinite, available.seconds >= 0.5 else {
            throw KaraokeVideoExportError.invalidBackgroundVideo
        }
        guard let target = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw KaraokeVideoExportError.cannotCreateTrack }

        var current = CMTime.zero
        while CMTimeCompare(current, duration) < 0 {
            try Task.checkCancellation()
            let remaining = CMTimeSubtract(duration, current)
            let clipDuration = CMTimeMinimum(available, remaining)
            try target.insertTimeRange(
                CMTimeRange(start: range.start, duration: clipDuration),
                of: source,
                at: current
            )
            current = CMTimeAdd(current, clipDuration)
        }
        target.preferredTransform = .identity
        return try await backgroundVideoLayout(for: source)
    }

    private func backgroundVideoLayout(for source: AVAssetTrack) async throws -> MovieTrackLayout {
        let naturalSize = try await source.load(.naturalSize)
        let transform = try await source.load(.preferredTransform)
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let width = abs(rect.width)
        let height = abs(rect.height)
        guard width.isFinite, height.isFinite, width >= 2, height >= 2 else {
            throw KaraokeVideoExportError.invalidVideoSize
        }

        let renderSize = KaraokeBackgroundMovie.size
        let scale = max(renderSize.width / width, renderSize.height / height)
        let finalWidth = width * scale
        let finalHeight = height * scale
        let normalized = transform
            .concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(
                translationX: (renderSize.width - finalWidth) / 2,
                y: (renderSize.height - finalHeight) / 2
            ))
        return MovieTrackLayout(size: renderSize, transform: normalized)
    }

    private func videoLayout(for source: AVAssetTrack) async throws -> MovieTrackLayout {
        let naturalSize = try await source.load(.naturalSize)
        let transform = try await source.load(.preferredTransform)
        let transformed = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let width = abs(transformed.width)
        let height = abs(transformed.height)
        guard width.isFinite, height.isFinite, width >= 2, height >= 2 else {
            throw KaraokeVideoExportError.invalidVideoSize
        }

        let scale = min(1, 1920 / max(width, height), 1080 / min(width, height))
        let renderWidth = max(2, floor(width * scale / 2) * 2)
        let renderHeight = max(2, floor(height * scale / 2) * 2)
        let normalized = transform
            .concatenating(CGAffineTransform(translationX: -transformed.minX, y: -transformed.minY))
            .concatenating(CGAffineTransform(scaleX: renderWidth / width, y: renderHeight / height))
        return MovieTrackLayout(
            size: CGSize(width: renderWidth, height: renderHeight),
            transform: normalized
        )
    }

    private func insertAudio(
        from asset: AVURLAsset,
        into composition: AVMutableComposition,
        duration: CMTime
    ) async throws {
        guard let source = try await asset.loadTracks(withMediaType: .audio).first else {
            throw KaraokeVideoExportError.noAudio
        }
        guard let target = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw KaraokeVideoExportError.cannotCreateTrack }
        let available = try await asset.load(.duration)
        try target.insertTimeRange(
            CMTimeRange(start: .zero, duration: CMTimeMinimum(available, duration)),
            of: source,
            at: .zero
        )
    }

    private func makeVideoComposition(
        composition: AVMutableComposition,
        layout: MovieTrackLayout,
        duration: CMTime,
        karaoke: KaraokeDocument
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = layout.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        if let video = composition.tracks(withMediaType: .video).first {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: video)
            layerInstruction.setTransform(layout.transform, at: .zero)
            instruction.layerInstructions = [layerInstruction]
        }
        videoComposition.instructions = [instruction]
        KaraokeExportOverlay.install(
            on: videoComposition,
            renderSize: layout.size,
            duration: duration.seconds,
            lyrics: karaoke.lines,
            style: karaoke.style?.sanitized() ?? .init()
        )
        return videoComposition
    }

    private func exportComposition(
        _ composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition,
        duration: CMTime,
        to destination: URL
    ) async throws {
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else { throw KaraokeVideoExportError.unavailableExportSession }
        guard session.supportedFileTypes.contains(.mp4) else { throw KaraokeVideoExportError.unsupportedMP4 }
        session.videoComposition = videoComposition
        session.timeRange = CMTimeRange(start: .zero, duration: duration)
        let staging = destination.deletingLastPathComponent().appendingPathComponent(
            ".meloman-\(UUID().uuidString).mp4"
        )
        let monitor = Task { @MainActor in
            for await state in session.states(updateInterval: 0.25) {
                guard !Task.isCancelled else { return }
                switch state {
                case let .exporting(progress):
                    onProgress?(
                        "Экспорт MP4",
                        "Кодирование видео с подсветкой слов",
                        progress.totalUnitCount > 0 ? progress.fractionCompleted : nil
                    )
                case .pending, .waiting:
                    onProgress?("Экспорт MP4", "Подготовка видеокодека", nil)
                @unknown default:
                    break
                }
            }
        }
        defer { monitor.cancel() }
        do {
            try await session.export(to: staging, as: .mp4)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
            } else {
                try FileManager.default.moveItem(at: staging, to: destination)
            }
            onProgress?("Экспорт завершён", destination.lastPathComponent, 1)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }
}
