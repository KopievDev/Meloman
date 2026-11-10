import AppKit
import MelomanDomain

/// V3 presents independently timed image/GIF segments over the song duration.
@MainActor
final class VisualOverlayTimelineStrip: NSView {
    var overlays: [VisualOverlay] = [] {
        didSet { needsDisplay = true }
    }

    var duration: Timecode = .zero {
        didSet { needsDisplay = true }
    }

    var playhead: Timecode = .zero {
        didSet { needsDisplay = true }
    }

    var selectedOverlayID: UUID? {
        didSet { needsDisplay = true }
    }

    var onSelect: ((UUID, Timecode) -> Void)?

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()
        for item in overlays {
            let rect = frame(for: item)
            guard rect.intersects(dirtyRect) else { continue }
            let color: NSColor = if item.id == selectedOverlayID {
                .systemYellow
            } else if item.isHidden {
                .secondaryLabelColor
            } else {
                .systemPurple
            }
            color.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        }
        let cursor = NSBezierPath()
        let x = position(for: playhead)
        cursor.move(to: CGPoint(x: x, y: 0))
        cursor.line(to: CGPoint(x: x, y: bounds.height))
        NSColor.systemRed.setStroke()
        cursor.lineWidth = 2
        cursor.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let chosen = overlays.reversed().first(where: { frame(for: $0).contains(point) }) else {
            return
        }
        onSelect?(chosen.id, chosen.start)
    }

    private func position(for time: Timecode) -> CGFloat {
        guard duration.microseconds > 0 else { return 0 }
        return CGFloat(Double(time.microseconds) / Double(duration.microseconds)) * bounds.width
    }

    private func frame(for overlay: VisualOverlay) -> CGRect {
        let x = position(for: overlay.start)
        return CGRect(x: x, y: 3, width: max(2, position(for: overlay.end) - x), height: bounds.height - 6)
    }
}
