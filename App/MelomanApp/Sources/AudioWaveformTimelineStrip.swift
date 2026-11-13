import AppKit
import MelomanDomain

/// Original audio A1 peaks, aligned with K1/K2/V3 on a shared time axis.
@MainActor
final class AudioWaveformTimelineStrip: NSView {
    var duration: Timecode = .zero {
        didSet { needsDisplay = true }
    }

    var waveform: AudioWaveform? {
        didSet { needsDisplay = true }
    }

    var message = "Выберите аудио или видео" {
        didSet { needsDisplay = true }
    }

    var playhead: Timecode = .zero {
        didSet { needsDisplay = true }
    }

    var onSeek: ((Timecode) -> Void)?

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()

        let center = bounds.midY
        NSColor.secondaryLabelColor.withAlphaComponent(0.3).setStroke()
        let axis = NSBezierPath()
        axis.move(to: NSPoint(x: 0, y: center))
        axis.line(to: NSPoint(x: bounds.maxX, y: center))
        axis.stroke()

        if let waveform, !waveform.peaks.isEmpty {
            drawPeaks(waveform.peaks, visible: dirtyRect)
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            (message as NSString).draw(at: NSPoint(x: 8, y: 9), withAttributes: attributes)
        }
        drawPlayhead()
    }

    private func drawPeaks(_ peaks: [Float], visible region: NSRect) {
        let step = bounds.width / CGFloat(peaks.count)
        guard step > 0 else { return }
        let lower = max(0, Int(floor(region.minX / step)))
        let upper = min(peaks.count, Int(ceil(region.maxX / step)) + 1)
        guard lower < upper else { return }

        let center = bounds.midY
        let height = max(1, (bounds.height - 5) * 0.48)
        let path = NSBezierPath()
        path.lineWidth = max(1, min(3, step * 0.8))
        for index in lower ..< upper {
            let amplitude = CGFloat(peaks[index]) * height
            let position = CGFloat(index) * step + step / 2
            path.move(to: NSPoint(x: position, y: center - amplitude))
            path.line(to: NSPoint(x: position, y: center + amplitude))
        }
        NSColor.systemGreen.withAlphaComponent(0.85).setStroke()
        path.stroke()
    }

    private func drawPlayhead() {
        guard duration.microseconds > 0 else { return }
        let position = CGFloat(playhead.microseconds) / CGFloat(duration.microseconds) * bounds.width
        NSColor.systemRed.setStroke()
        let cursor = NSBezierPath()
        cursor.lineWidth = 2
        cursor.move(to: NSPoint(x: position, y: 0))
        cursor.line(to: NSPoint(x: position, y: bounds.height))
        cursor.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        seek(at: event)
    }

    override func mouseDragged(with event: NSEvent) {
        seek(at: event)
    }

    private func seek(at event: NSEvent) {
        guard duration.microseconds > 0, bounds.width > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        let ratio = min(1, max(0, point.x / bounds.width))
        let micros = Int64((Double(duration.microseconds) * Double(ratio)).rounded())
        if let time = Timecode(microseconds: micros) {
            onSeek?(time)
        }
    }
}
