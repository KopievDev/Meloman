import AppKit
import AVFoundation

/// Black canvas for audio-only projects, AVPlayerLayer for video.
@MainActor
final class MediaPreviewView: NSView {
    let playerLayer = AVPlayerLayer()
    let imageLayer = CALayer()
    let karaokeOverlay = KaraokeOverlayView()

    var backgroundImage: NSImage? {
        didSet {
            imageLayer.contents = backgroundImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    override func layout() {
        super.layout()
        imageLayer.frame = bounds
        playerLayer.frame = bounds
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.masksToBounds = true
        layer?.addSublayer(imageLayer)
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
        karaokeOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(karaokeOverlay)
        NSLayoutConstraint.activate([
            karaokeOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            karaokeOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            karaokeOverlay.topAnchor.constraint(equalTo: topAnchor),
            karaokeOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
