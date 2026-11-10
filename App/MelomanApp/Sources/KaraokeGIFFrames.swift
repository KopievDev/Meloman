import CoreGraphics
import Foundation
import ImageIO
import MelomanDomain

/// Reads a GIF's source delays and lazily decodes frames at preview resolution.
/// Cache is bounded so long GIFs don't permanently occupy excessive RAM.
@MainActor
final class KaraokeGIFFrames {
    private let source: CGImageSource
    private var cache: [Int: CGImage] = [:]
    private var cachedIndices: [Int] = []
    private let cacheLimit = 16

    let timing: GIFPlaybackTiming
    private(set) var lastDisplayedIndex: Int?

    init?(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0, count <= 1200 else { return nil }
        var delays: [Double] = []
        for index in 0 ..< count {
            let info = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
            let properties = info?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let raw = properties?[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber
            let fallback = properties?[kCGImagePropertyGIFDelayTime as String] as? NSNumber
            delays.append(raw?.doubleValue ?? fallback?.doubleValue ?? 0.1)
        }
        self.source = source
        timing = GIFPlaybackTiming(frameDurations: delays)
    }

    func frame(at seconds: Double) -> CGImage? {
        guard let index = timing.frameIndex(at: seconds) else { return nil }
        return frame(index: index)
    }

    func frame(index: Int) -> CGImage? {
        guard timing.durations.indices.contains(index) else { return nil }
        lastDisplayedIndex = index
        if let image = cache[index] {
            return image
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1280,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(source, index, nil)
        else { return nil }
        cache[index] = image
        cachedIndices.append(index)
        if cachedIndices.count > cacheLimit {
            let oldest = cachedIndices.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        return image
    }
}
