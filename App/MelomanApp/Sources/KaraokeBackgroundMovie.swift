import AVFoundation
import CoreVideo
import Foundation

enum KaraokeBackgroundError: LocalizedError {
    case noPixelBufferPool
    case cannotCreateFrame
    case encodingFailed

    var errorDescription: String? {
        "Не удалось создать видеодорожку для караоке на аудиофайле."
    }
}

/// A sparse 1 fps black video is sufficient as the background track.
/// AVVideoComposition produces final 30 fps video with animated karaoke on top.
@MainActor
enum KaraokeBackgroundMovie {
    static let size = CGSize(width: 1280, height: 720)

    static func make(duration: CMTime, at output: URL) async throws -> URL {
        let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? KaraokeBackgroundError.encodingFailed }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else { throw KaraokeBackgroundError.noPixelBufferPool }
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer
        else { throw KaraokeBackgroundError.cannotCreateFrame }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let address = CVPixelBufferGetBaseAddress(buffer) {
            memset(address, 0, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let frames = max(1, Int(ceil(duration.seconds)))
        for index in 0 ..< frames {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            let time = CMTime(value: Int64(index), timescale: 1)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? KaraokeBackgroundError.encodingFailed
            }
        }

        writer.endSession(atSourceTime: duration)
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? KaraokeBackgroundError.encodingFailed }
        return output
    }
}
