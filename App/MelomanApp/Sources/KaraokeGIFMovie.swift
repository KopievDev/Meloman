import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

enum KaraokeGIFError: LocalizedError {
    case invalidGIF
    case missingPixelBuffer
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidGIF:
            "GIF не содержит декодируемых кадров."
        case .missingPixelBuffer:
            "Не удалось подготовить видеокадр GIF."
        case .encodingFailed:
            "Не удалось преобразовать GIF в видео."
        }
    }
}

/// Makes one variable-frame-rate silent movie cycle from an animated GIF.
/// The common video exporter repeats this cycle over the whole song duration.
@MainActor
enum KaraokeGIFMovie {
    static func make(source url: URL, at output: URL) async throws -> URL {
        guard let gif = KaraokeGIFFrames(url: url),
              gif.timing.totalDuration.isFinite,
              gif.timing.totalDuration > 0
        else { throw KaraokeGIFError.invalidGIF }

        let size = KaraokeBackgroundMovie.size
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
        guard writer.startWriting() else { throw writer.error ?? KaraokeGIFError.encodingFailed }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw KaraokeGIFError.missingPixelBuffer }

        do {
            try await appendFrames(gif: gif, pool: pool, input: input, adaptor: adaptor, writer: writer)
            writer.endSession(atSourceTime: CMTime(seconds: gif.timing.totalDuration, preferredTimescale: 60000))
            input.markAsFinished()
            await withCheckedContinuation { continuation in
                writer.finishWriting {
                    continuation.resume()
                }
            }
            guard writer.status == .completed else { throw writer.error ?? KaraokeGIFError.encodingFailed }
            return output
        } catch {
            writer.cancelWriting()
            throw error
        }
    }

    private static func appendFrames(
        gif: KaraokeGIFFrames,
        pool: CVPixelBufferPool,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writer: AVAssetWriter
    ) async throws {
        let size = KaraokeBackgroundMovie.size
        var elapsed = 0.0
        for index in gif.timing.durations.indices {
            try Task.checkCancellation()
            guard let image = gif.frame(index: index) else { throw KaraokeGIFError.invalidGIF }
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
                  let buffer = pixelBuffer
            else { throw KaraokeGIFError.missingPixelBuffer }

            try draw(image, into: buffer, size: size)
            let time = CMTime(seconds: elapsed, preferredTimescale: 60000)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? KaraokeGIFError.encodingFailed
            }
            elapsed += gif.timing.durations[index]
        }
    }

    private static func draw(_ image: CGImage, into buffer: CVPixelBuffer, size: CGSize) throws {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let address = CVPixelBufferGetBaseAddress(buffer) else { throw KaraokeGIFError.missingPixelBuffer }

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: address,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { throw KaraokeGIFError.missingPixelBuffer }

        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = max(size.width / width, size.height / height)
        let frame = CGRect(
            x: (size.width - width * scale) / 2,
            y: (size.height - height * scale) / 2,
            width: width * scale,
            height: height * scale
        )
        context.interpolationQuality = .high
        context.draw(image, in: frame)
    }
}
