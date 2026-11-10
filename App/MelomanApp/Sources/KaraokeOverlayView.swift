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

    var style = KaraokeStyle() {
        didSet { needsDisplay = true }
    }

    var pronunciation = KaraokePronunciationTrack() {
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
        guard bounds.width > 40, let context = NSGraphicsContext.current?.cgContext else { return }
        let display = KaraokeDisplayEngine.frame(at: playhead, lines: lyrics)
        let track = pronunciation.isEnabled ? pronunciation : nil
        if let current = display.current {
            drawRow(current, row: .current, in: context, track: track)
            if track != nil {
                drawRow(current, row: .current, in: context, track: track, phonetic: true)
            }
        }
        if let upcoming = display.upcoming {
            drawRow(upcoming, row: .upcoming, in: context, track: track)
            if track != nil {
                drawRow(upcoming, row: .upcoming, in: context, track: track, phonetic: true)
            }
        }
    }

    private func drawRow(
        _ frame: KaraokeFrame,
        row: KaraokeDisplayRow,
        in context: CGContext,
        track: KaraokePronunciationTrack?,
        phonetic: Bool = false
    ) {
        let values = renderedValues(for: frame, track: track, phonetic: phonetic)
        guard values.contains(where: { !$0.isEmpty }) else { return }
        let fullText = values.joined(separator: " ")
        let mainFont = KaraokeStyleRendering.font(for: style, width: bounds.width)
        let font = phonetic
            ? KaraokeStyleRendering.pronunciationFont(for: style, width: bounds.width)
            : mainFont
        let base = createLine(fullText, font: font, color: rowColor(row: row, phonetic: phonetic))

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(base, &ascent, &descent, nil))
        guard width > 0 else { return }

        let scale = min(1, max(0.01, (bounds.width - 36) / width))
        let originX = max(18, (bounds.width - width * scale) / 2)
        let baselineY = rowBaseline(
            row: row, phonetic: phonetic, track: track, mainFont: mainFont
        )
        beginDrawing(context, originX: originX, baselineY: baselineY, scale: scale, line: base)

        if row == .current {
            let color = KaraokeStyleRendering.color(style.highlightColor)
            let fill = createLine(fullText, font: font, color: phonetic ? color.withAlphaComponent(0.85) : color)
            drawHighlights(
                HighlightContent(
                    words: frame.words,
                    values: values,
                    base: base,
                    fill: fill,
                    ascent: ascent,
                    descent: descent
                ),
                in: context
            )
        }
        context.restoreGState()
    }

    private func renderedValues(
        for frame: KaraokeFrame,
        track: KaraokePronunciationTrack?,
        phonetic: Bool
    ) -> [String] {
        frame.words.map { word in
            if word.isHidden {
                return "____"
            }
            return phonetic ? (track?.text(for: word.id) ?? "") : word.text
        }
    }

    private func rowColor(row: KaraokeDisplayRow, phonetic: Bool) -> NSColor {
        let normal = KaraokeStyleRendering.color(style.textColor)
        if phonetic {
            return normal.withAlphaComponent(row == .current ? 0.85 : 0.52)
        }
        return row == .current ? normal : normal.withAlphaComponent(0.68)
    }

    private func rowBaseline(
        row: KaraokeDisplayRow,
        phonetic: Bool,
        track: KaraokePronunciationTrack?,
        mainFont: CTFont
    ) -> CGFloat {
        let fontSize = CGFloat(CTFontGetSize(mainFont))
        if phonetic {
            return KaraokeStyleRendering.pronunciationBaseline(
                for: row, style: style, size: bounds.size, mainFontSize: fontSize
            )
        }
        return KaraokeStyleRendering.baseline(
            for: row, style: style, size: bounds.size, fontSize: fontSize,
            pronunciationEnabled: track != nil
        )
    }

    private struct HighlightContent {
        let words: [KaraokeWordFrame]
        let values: [String]
        let base: CTLine
        let fill: CTLine
        let ascent: CGFloat
        let descent: CGFloat
    }

    private func drawHighlights(_ highlight: HighlightContent, in context: CGContext) {
        var offset = 0
        for (index, value) in highlight.values.enumerated() {
            let word = highlight.words[index]
            let startX = CTLineGetOffsetForStringIndex(highlight.base, offset, nil)
            offset += (value as NSString).length
            let endX = CTLineGetOffsetForStringIndex(highlight.base, offset, nil)

            if !word.isHidden, word.progress > 0 {
                context.saveGState()
                let clip = CGRect(
                    x: startX,
                    y: -highlight.descent - 2,
                    width: max(0, endX - startX) * CGFloat(word.progress),
                    height: highlight.ascent + highlight.descent + 5
                )
                context.clip(to: clip)
                context.textPosition = .zero
                CTLineDraw(highlight.fill, context)
                context.restoreGState()
            }

            if index < highlight.values.count - 1 {
                offset += 1 // UTF-16 space separator
            }
        }
    }

    private func beginDrawing(
        _ context: CGContext,
        originX: CGFloat,
        baselineY: CGFloat,
        scale: CGFloat,
        line: CTLine
    ) {
        context.saveGState()
        context.translateBy(x: originX, y: baselineY)
        context.scaleBy(x: scale, y: scale)
        context.textMatrix = .identity
        context.textPosition = .zero
        context.setShadow(offset: CGSize(width: 1, height: -2), blur: 5, color: NSColor.black.cgColor)
        CTLineDraw(line, context)
        context.setShadow(offset: .zero, blur: 0, color: nil)
    }

    private func createLine(_ string: String, font: CTFont, color: NSColor) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
    }
}
