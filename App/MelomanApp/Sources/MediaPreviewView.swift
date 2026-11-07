import AppKit
import AVFoundation

/// Black canvas for audio-only projects, AVPlayerLayer for video.
@MainActor
final class MediaPreviewView: NSView {
    let playerLayer = AVPlayerLayer()
    let karaokeOverlay = KaraokeOverlayView()

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
        playerLayer.frame = bounds
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
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
