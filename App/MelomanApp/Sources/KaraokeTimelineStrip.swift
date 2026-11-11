import AppKit
import MelomanDomain

/// Scrollable time-scaled K1 word track. Clicking a word selects and seeks it.
@MainActor
final class KaraokeTimelineStrip: NSView {
    var lines: [LyricLine] = [] {
        didSet { needsDisplay = true }
    }

    /// Non-nil switches this instance to the optional K2 phonetic word track.
    var pronunciation: KaraokePronunciationTrack? {
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
    var onEditPreview: ((UUID, [LyricLine]) -> Void)?
    var onEditCommit: ((UUID, [LyricLine]) -> Void)?
    var onEditCancel: (() -> Void)?
    var isTimingEditEnabled = false

    private struct DragSession {
        let wordID: UUID
        let original: [LyricLine]
        let originX: CGFloat
        let anchor: Timecode
        let mode: LyricTimingEditMode
        var didDrag = false
        var latest: [LyricLine]?
    }

    private var dragSession: DragSession?

    override var acceptsFirstResponder: Bool {
        true
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()
        for word in lines.flatMap(\.words) {
            drawWord(word, in: dirtyRect)
        }
        let cursorX = xPosition(playhead)
        NSColor.systemRed.setStroke()
        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: cursorX, y: 0))
        cursor.line(to: NSPoint(x: cursorX, y: bounds.height))
        cursor.lineWidth = 2
        cursor.stroke()
    }

    private func drawWord(_ word: LyricWord, in dirtyRect: NSRect) {
        let rect = rectForWord(word)
        guard rect.intersects(dirtyRect), rect.width > 0 else { return }
        let selected = word.id == selectedWordID
        wordColor(word, selected: selected).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        if selected, isTimingEditEnabled, rect.width >= 20 {
            drawWordHandles(in: rect)
        }
        if rect.width > 24 {
            drawWordTitle(word, in: rect)
        }
    }

    private func wordColor(_ word: LyricWord, selected: Bool) -> NSColor {
        if selected {
            return .systemYellow
        }
        if let confidence = word.alignmentConfidence, confidence < 0.25 {
            return NSColor.systemOrange.withAlphaComponent(0.75)
        }
        if pronunciation != nil {
            return NSColor.systemIndigo.withAlphaComponent(pronunciation?.isEnabled == true ? 0.75 : 0.25)
        }
        return NSColor.systemTeal.withAlphaComponent(0.65)
    }

    private func drawWordHandles(in rect: NSRect) {
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(rect: NSRect(
            x: rect.minX + 3, y: rect.minY + 5, width: 2, height: rect.height - 10
        )).fill()
        NSBezierPath(rect: NSRect(
            x: rect.maxX - 5, y: rect.minY + 5, width: 2, height: rect.height - 10
        )).fill()
    }

    private func drawWordTitle(_ word: LyricWord, in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let title = if word.isHidden {
            "____"
        } else {
            pronunciation?.text(for: word.id) ?? (pronunciation == nil ? word.text : "")
        }
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

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let chosen = lines.flatMap(\.words).first(where: { rectForWord($0).contains(point) }) else {
            return
        }
        guard isTimingEditEnabled, onEditCommit != nil else {
            onSelect?(chosen.id, chosen.start)
            return
        }
        window?.makeFirstResponder(self)
        let mode = dragMode(for: chosen, at: point, modifiers: event.modifierFlags)
        let anchor = mode == .trimEnd ? chosen.end : chosen.start
        dragSession = DragSession(
            wordID: chosen.id, original: lines, originX: point.x,
            anchor: anchor, mode: mode
        )
        selectedWordID = chosen.id
    }

    override func mouseDragged(with event: NSEvent) {
        guard var drag = dragSession,
              duration.microseconds > 0,
              bounds.width > 0
        else { return }
        let point = convert(event.locationInWindow, from: nil)
        let distance = point.x - drag.originX
        guard drag.didDrag || abs(distance) >= 3 else { return }
        drag.didDrag = true

        let raw = (Double(distance) / Double(bounds.width)) * Double(duration.microseconds)
        let safe = max(Double(Int64.min) + 1, min(Double(Int64.max) - 1024, raw))
        var delta = Int64(safe.rounded())
        if !event.modifierFlags.contains(.shift) {
            delta = LyricTimingEditor.snappedDelta(from: drag.anchor, proposedDelta: delta)
        }
        if let edited = LyricTimingEditor.applying(
            drag.mode, to: drag.wordID, in: drag.original,
            deltaMicroseconds: delta, mediaDuration: duration
        ) {
            drag.latest = edited
            onEditPreview?(drag.wordID, edited)
        }
        dragSession = drag
    }

    override func mouseUp(with _: NSEvent) {
        guard let drag = dragSession else { return }
        dragSession = nil
        if drag.didDrag {
            if let edited = drag.latest, edited != drag.original {
                onEditCommit?(drag.wordID, edited)
            } else {
                onEditCancel?()
            }
        } else if let word = drag.original.flatMap(\.words).first(where: { $0.id == drag.wordID }) {
            onSelect?(word.id, word.start)
        }
    }

    override func cancelOperation(_: Any?) {
        guard dragSession != nil else { return }
        dragSession = nil
        onEditCancel?()
    }

    private func dragMode(
        for word: LyricWord,
        at point: NSPoint,
        modifiers: NSEvent.ModifierFlags
    ) -> LyricTimingEditMode {
        if modifiers.contains(.option) {
            return .moveLine
        }
        let frame = rectForWord(word)
        guard frame.width >= 20 else { return .moveWord }
        let edge = min(9, frame.width / 4)
        if point.x - frame.minX <= edge {
            return .trimStart
        }
        if frame.maxX - point.x <= edge {
            return .trimEnd
        }
        return .moveWord
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
