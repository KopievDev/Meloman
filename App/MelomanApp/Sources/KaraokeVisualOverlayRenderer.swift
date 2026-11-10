import AppKit
import AVFoundation
import MelomanDomain

struct KaraokeOverlayAsset {
    let overlay: VisualOverlay
    let url: URL
}

/// Core Animation graphic layers are placed above the footage but below
/// karaoke text, with timing anchored to the exported media timeline.
@MainActor
enum KaraokeVisualOverlayRenderer {
    static func install(
        on parent: CALayer,
        size: CGSize,
        duration: Double,
        assets: [KaraokeOverlayAsset]
    ) {
        for asset in assets where !asset.overlay.isHidden {
            let item = asset.overlay
            guard let image = firstImage(for: asset) else { continue }
            let width = size.width * item.width
            let height = width * CGFloat(image.height) / CGFloat(image.width)
            let layer = CALayer()
            layer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            layer.position = CGPoint(x: size.width * item.centerX, y: size.height * item.centerY)
            layer.contents = image
            layer.contentsGravity = .resizeAspect
            layer.masksToBounds = true
            layer.opacity = 0
            layer.add(visibility(for: item, duration: duration), forKey: "visibility")

            if item.fileExtension == "gif", let gif = KaraokeGIFFrames(url: asset.url) {
                animateGIF(gif, on: layer, start: Double(item.start.microseconds) / 1_000_000)
            }
            parent.addSublayer(layer)
        }
    }

    private static func firstImage(for asset: KaraokeOverlayAsset) -> CGImage? {
        if asset.overlay.fileExtension == "gif" {
            return KaraokeGIFFrames(url: asset.url)?.frame(index: 0)
        }
        return NSImage(contentsOf: asset.url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func animateGIF(_ gif: KaraokeGIFFrames, on layer: CALayer, start: Double) {
        guard gif.timing.durations.count > 1 else { return }
        let indices = Array(gif.timing.durations.indices)
        let images = indices.compactMap { gif.frame(index: $0) }
        guard images.count == indices.count else { return }

        var elapsed = 0.0
        var times: [NSNumber] = []
        for duration in gif.timing.durations {
            times.append(NSNumber(value: elapsed / gif.timing.totalDuration))
            elapsed += duration
        }
        times.append(1)
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = images.map { $0 as Any } + [images[images.count - 1]]
        animation.keyTimes = times
        animation.calculationMode = .discrete
        animation.duration = gif.timing.totalDuration
        animation.beginTime = AVCoreAnimationBeginTimeAtZero + start
        animation.repeatCount = .greatestFiniteMagnitude
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: "gif-frames")
    }

    private static func visibility(for overlay: VisualOverlay, duration: Double) -> CAKeyframeAnimation {
        let begin = max(0, min(1, Double(overlay.start.microseconds) / 1_000_000 / duration))
        let end = max(0, min(1, Double(overlay.end.microseconds) / 1_000_000 / duration))
        var times = [0.0]
        var values = [begin == 0 ? 1 : 0]
        if begin > 0 {
            times.append(begin)
            values.append(1)
        }
        if end < 1 {
            times.append(end)
            values.append(0)
        }
        if times.last != 1 {
            times.append(1)
            values.append(values.last ?? 0)
        }
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = values.map { NSNumber(value: $0) }
        animation.keyTimes = times.map { NSNumber(value: $0) }
        animation.calculationMode = .discrete
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.duration = duration
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        return animation
    }
}
