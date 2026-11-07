import AppKit
import CoreText
import KaraokeEngine
import MelomanDomain

/// AppKit word-fill renderer. CoreText is used for glyph-accurate UTF-16 offsets;
/// no fixed-width approximations or subtitle-style whole-line color switching.
@MainActor
final class KaraokeOverlayView: NSView {
    var lyrics: [LyricLine] = [] {
        didSet { needsDisplay = true }
    }

    var playhead: Timecode = .zero {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 40,
              let frame = KaraokeEngine.frame(at: playhead, lines: lyrics),
              let context = NSGraphicsContext.current?.cgContext
        else { return }

        let values = frame.words.map { $0.isHidden ? "____" : $0.text }
        let fullText = values.joined(separator: " ")
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 40, nil)
        let base = createLine(fullText, font: font, color: .white)
        let fill = createLine(fullText, font: font, color: NSColor.systemYellow)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(base, &ascent, &descent, nil))
        guard width > 0 else { return }

        let scale = min(1, max(0.01, (bounds.width - 36) / width))
        let x = max(18, (bounds.width - width * scale) / 2)
        let y = max(42, min(86, bounds.height * 0.18))

        context.saveGState()
        context.translateBy(x: x, y: y)
        context.scaleBy(x: scale, y: scale)
        context.textMatrix = .identity
        context.textPosition = .zero
        context.setShadow(offset: CGSize(width: 1, height: -2), blur: 5, color: NSColor.black.cgColor)
        CTLineDraw(base, context)
        context.setShadow(offset: .zero, blur: 0, color: nil)

        var offset = 0
        for (index, value) in values.enumerated() {
            let word = frame.words[index]
            let startX = CTLineGetOffsetForStringIndex(base, offset, nil)
            offset += (value as NSString).length
            let endX = CTLineGetOffsetForStringIndex(base, offset, nil)

            if !word.isHidden, word.progress > 0 {
                context.saveGState()
                let clip = CGRect(
                    x: startX,
                    y: -descent - 2,
                    width: max(0, endX - startX) * CGFloat(word.progress),
                    height: ascent + descent + 5
                )
                context.clip(to: clip)
                context.textPosition = .zero
                CTLineDraw(fill, context)
                context.restoreGState()
            }

            if index < values.count - 1 {
                offset += 1 // UTF-16 space separator
            }
        }
        context.restoreGState()
    }

    private func createLine(_ string: String, font: CTFont, color: NSColor) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
    }
}
