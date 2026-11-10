import AppKit
import MelomanDomain

@MainActor
extension MediaPreviewView {
    func setVisualOverlays(_ overlays: [VisualOverlay], urls: [UUID: URL]) {
        visualOverlayRoot.sublayers?.forEach { $0.removeFromSuperlayer() }
        visualItems = overlays
        visualImageLayers.removeAll()
        visualGIFFrames.removeAll()
        visualImageSizes.removeAll()

        for item in overlays {
            guard let url = urls[item.id] else { continue }
            let image: CGImage?
            if item.fileExtension == "gif", let frames = KaraokeGIFFrames(url: url) {
                visualGIFFrames[item.id] = frames
                image = frames.frame(index: 0)
            } else {
                image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
            guard let image else { continue }
            let layer = CALayer()
            layer.contents = image
            layer.contentsGravity = .resizeAspect
            layer.masksToBounds = true
            layer.isHidden = true
            visualOverlayRoot.addSublayer(layer)
            visualImageLayers[item.id] = layer
            visualImageSizes[item.id] = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        }
        layoutVisualOverlays()
    }

    func layoutVisualOverlays() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for item in visualItems {
            guard let layer = visualImageLayers[item.id],
                  let size = visualImageSizes[item.id],
                  size.width > 0
            else { continue }
            let width = bounds.width * item.width
            layer.bounds = CGRect(x: 0, y: 0, width: width, height: width * size.height / size.width)
            layer.position = CGPoint(x: bounds.width * item.centerX, y: bounds.height * item.centerY)
        }
        CATransaction.commit()
    }

    func updateVisualOverlays(at seconds: Double) {
        guard seconds.isFinite, seconds >= 0 else { return }
        let time = Timecode(microseconds: Int64((seconds * 1_000_000).rounded())) ?? .zero
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for item in visualItems {
            guard let layer = visualImageLayers[item.id] else { continue }
            let active = item.isActive(at: time)
            layer.isHidden = !active
            if active, let gif = visualGIFFrames[item.id] {
                let relative = seconds - Double(item.start.microseconds) / 1_000_000
                if gif.timing.frameIndex(at: relative) != gif.lastDisplayedIndex {
                    layer.contents = gif.frame(at: relative)
                }
            }
        }
        CATransaction.commit()
    }
}
