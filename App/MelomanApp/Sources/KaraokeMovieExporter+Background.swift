@preconcurrency import AVFoundation
import Foundation

@MainActor
extension KaraokeMovieExporter {
    func insertLoopedBackgroundVideo(
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
}
