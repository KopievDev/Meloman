import AppKit
import AVFoundation

/// Black canvas for audio-only projects, AVPlayerLayer for video.
@MainActor
final class MediaPreviewView: NSView {
    let playerLayer = AVPlayerLayer()
    let imageLayer = CALayer()
    let backgroundVideoLayer = AVPlayerLayer()
    let karaokeOverlay = KaraokeOverlayView()

    var backgroundGIF: KaraokeGIFFrames? {
        didSet {
            imageLayer.contents = backgroundGIF?.frame(at: 0)
        }
    }

    func updateAnimatedGIF(at seconds: Double) {
        guard let backgroundGIF else { return }
        let index = backgroundGIF.timing.frameIndex(at: seconds)
        if index != backgroundGIF.lastDisplayedIndex {
            imageLayer.contents = backgroundGIF.frame(at: seconds)
        }
    }

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
        backgroundVideoLayer.frame = bounds
        playerLayer.frame = bounds
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.masksToBounds = true
        layer?.addSublayer(imageLayer)
        backgroundVideoLayer.videoGravity = .resizeAspectFill
        backgroundVideoLayer.isHidden = true
        layer?.addSublayer(backgroundVideoLayer)
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
