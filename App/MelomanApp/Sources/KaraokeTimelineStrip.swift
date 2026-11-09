import AppKit
import MelomanDomain

/// Scrollable time-scaled K1 word track. Clicking a word selects and seeks it.
@MainActor
final class KaraokeTimelineStrip: NSView {
    var lines: [LyricLine] = [] {
        didSet { needsDisplay = true }
    }

    var duration: Timecode = .zero {
        didSet { needsDisplay = true }
    }

    var playhead: Timecode = .zero {
        didSet { needsDisplay = true }
    }

    var selectedWordID: UUID? {
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

        for word in lines.flatMap(\.words) {
            let rect = rectForWord(word)
            guard rect.intersects(dirtyRect), rect.width > 0 else { continue }
            let selected = word.id == selectedWordID
            let fill: NSColor = if selected {
                .systemYellow
            } else if let confidence = word.alignmentConfidence, confidence < 0.25 {
                NSColor.systemOrange.withAlphaComponent(0.75)
            } else {
                NSColor.systemTeal.withAlphaComponent(0.65)
            }
            fill.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

            if rect.width > 24 {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byTruncatingTail
                let title = word.isHidden ? "____" : word.text
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: paragraph,
                ]
                (title as NSString).draw(
                    in: rect.insetBy(dx: 4, dy: 6),
                    withAttributes: attributes
                )
            }
        }

        let cursorX = xPosition(playhead)
        NSColor.systemRed.setStroke()
        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: cursorX, y: 0))
        cursor.line(to: NSPoint(x: cursorX, y: bounds.height))
        cursor.lineWidth = 2
        cursor.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let chosen = lines.flatMap(\.words).first(where: { rectForWord($0).contains(point) }) else {
            return
        }
        onSelect?(chosen.id, chosen.start)
    }

    private func xPosition(_ time: Timecode) -> CGFloat {
        guard duration.microseconds > 0 else { return 0 }
        return CGFloat(Double(time.microseconds) / Double(duration.microseconds)) * bounds.width
    }

    private func rectForWord(_ word: LyricWord) -> NSRect {
        let startX = xPosition(word.start)
        let end = xPosition(word.end)
        return NSRect(x: startX, y: 4, width: max(1, end - startX - 1), height: max(12, bounds.height - 8))
    }
}
