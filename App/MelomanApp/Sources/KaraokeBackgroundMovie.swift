import AppKit
import AVFoundation
import CoreVideo
import Foundation

enum KaraokeBackgroundError: LocalizedError {
    case noPixelBufferPool
    case cannotCreateFrame
    case encodingFailed
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .noPixelBufferPool, .cannotCreateFrame, .encodingFailed:
            "Не удалось создать видеодорожку для караоке на аудиофайле."
        case .invalidImage:
            "Изображение фона повреждено или не поддерживается."
        }
    }
}

/// A sparse 1 fps still-image (or black) video is sufficient as the background track.
/// AVVideoComposition produces final 30 fps video with animated karaoke on top.
@MainActor
enum KaraokeBackgroundMovie {
    static let size = CGSize(width: 1280, height: 720)

    static func make(duration: CMTime, at output: URL, imageURL: URL? = nil) async throws -> URL {
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

        try drawBackground(in: buffer, imageURL: imageURL)

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
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
        guard writer.status == .completed else { throw writer.error ?? KaraokeBackgroundError.encodingFailed }
        return output
    }

    private static func drawBackground(in buffer: CVPixelBuffer, imageURL: URL?) throws {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let address = CVPixelBufferGetBaseAddress(buffer) else {
            throw KaraokeBackgroundError.cannotCreateFrame
        }
        memset(address, 0, CVPixelBufferGetDataSize(buffer))
        guard let imageURL else { return }
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw KaraokeBackgroundError.invalidImage }

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: address,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { throw KaraokeBackgroundError.cannotCreateFrame }

        let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let target = CGRect(
            x: (size.width - imageSize.width * scale) / 2,
            y: (size.height - imageSize.height * scale) / 2,
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        context.interpolationQuality = .high
        context.draw(cgImage, in: target)
    }
}
