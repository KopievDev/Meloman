import AppKit
import AVFoundation
import CoreText
import KaraokeEngine
import MelomanDomain
import QuartzCore

/// Core Animation export overlay uses the same CoreText glyph offsets as
/// KaraokeOverlayView. Animations run on the media timeline, not wall-clock time.
@MainActor
enum KaraokeExportOverlay {
    static func install(
        on videoComposition: AVMutableVideoComposition,
        renderSize: CGSize,
        duration: Double,
        karaoke: KaraokeDocument,
        overlays: [KaraokeOverlayAsset]
    ) {
        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: renderSize)
        parent.masksToBounds = true

        let video = CALayer()
        video.frame = parent.bounds
        parent.addSublayer(video)
        KaraokeVisualOverlayRenderer.install(
            on: parent, size: renderSize, duration: duration, assets: overlays
        )

        if let timecode = Timecode(microseconds: Int64((duration * 1_000_000).rounded())) {
            for cue in KaraokeDisplayTimeline.cues(from: karaoke.lines, duration: timecode) {
                if let layer = makeLine(
                    cue,
                    size: renderSize,
                    duration: duration,
                    style: karaoke.style?.sanitized() ?? .init()
                ) {
                    parent.addSublayer(layer)
                }
            }
        }
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: video,
            in: parent
        )
    }

    private static func makeLine(
        _ cue: KaraokeDisplayCue,
        size: CGSize,
        duration: Double,
        style: KaraokeStyle
    ) -> CALayer? {
        let values = cue.line.words.map { $0.isHidden ? "____" : $0.text }
        let text = values.joined(separator: " ")
        let font = KaraokeStyleRendering.font(for: style, width: size.width)
        let fontSize = CGFloat(CTFontGetSize(font))
        let normalColor = KaraokeStyleRendering.color(style.textColor)
        let color = cue.row == .current ? normalColor : normalColor.withAlphaComponent(0.68)
        let measure = attributedText(text, font: font, color: color)
        let ctLine = CTLineCreateWithAttributedString(measure)
        let width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
        guard width > 0 else { return nil }

        let scale = min(1, max(0.01, (size.width - 36) / width))
        let height = fontSize * 1.5
        let root = CALayer()
        root.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        root.position = CGPoint(
            x: size.width / 2,
            y: KaraokeStyleRendering.baseline(
                for: cue.row,
                style: style,
                size: size,
                fontSize: fontSize
            ) + height * scale / 2
        )
        root.transform = CATransform3DMakeScale(scale, scale, 1)
        root.opacity = 0
        root.add(visibilityAnimation(for: cue, duration: duration), forKey: "visibility")
        root.addSublayer(textLayer(measure, width: width, height: height))

        if cue.row == .current {
            addWordHighlights(
                to: root,
                cue: cue,
                visible: values,
                measured: ctLine,
                appearance: HighlightAppearance(
                    font: font,
                    color: KaraokeStyleRendering.color(style.highlightColor)
                )
            )
        }
        return root
    }

    private struct HighlightAppearance {
        let font: CTFont
        let color: NSColor
    }

    private static func addWordHighlights(
        to root: CALayer,
        cue: KaraokeDisplayCue,
        visible: [String],
        measured: CTLine,
        appearance: HighlightAppearance
    ) {
        let fullText = visible.joined(separator: " ")
        let height = root.bounds.height
        let words = cue.line.words
        var offset = 0
        for (index, word) in words.enumerated() {
            let start = CTLineGetOffsetForStringIndex(measured, offset, nil)
            offset += (visible[index] as NSString).length
            let end = CTLineGetOffsetForStringIndex(measured, offset, nil)

            if !word.isHidden, end > start {
                let highlight = attributedText(
                    fullText,
                    font: appearance.font,
                    color: appearance.color
                )
                let layer = textLayer(highlight, width: root.bounds.width, height: height)
                let mask = CALayer()
                mask.backgroundColor = NSColor.white.cgColor
                mask.anchorPoint = CGPoint(x: 0, y: 0)
                mask.position = CGPoint(x: start, y: 0)
                mask.bounds = CGRect(x: 0, y: 0, width: 0, height: height)
                mask.add(fillAnimation(word, width: end - start), forKey: "fill")
                layer.mask = mask
                root.addSublayer(layer)
            }
            if index < words.count - 1 {
                offset += 1 // UTF-16 separator between words
            }
        }
    }

    private static func textLayer(
        _ attributed: NSAttributedString,
        width: CGFloat,
        height: CGFloat
    ) -> CATextLayer {
        let layer = CATextLayer()
        layer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        layer.string = attributed
        layer.alignmentMode = .left
        layer.contentsScale = 2
        layer.isWrapped = false
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.8
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 1, height: -2)
        return layer
    }

    private static func attributedText(
        _ text: String,
        font: CTFont,
        color: NSColor
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ])
    }

    private static func fillAnimation(_ word: LyricWord, width: CGFloat) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "bounds.size.width")
        animation.beginTime = AVCoreAnimationBeginTimeAtZero + Double(word.start.microseconds) / 1_000_000
        animation.duration = max(0.001, Double(word.end.microseconds - word.start.microseconds) / 1_000_000)
        animation.fromValue = 0
        animation.toValue = width
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        return animation
    }

    private static func visibilityAnimation(
        for cue: KaraokeDisplayCue,
        duration: Double
    ) -> CAKeyframeAnimation {
        let begin = max(0, min(1, Double(cue.start.microseconds) / 1_000_000 / duration))
        let end = max(0, min(1, Double(cue.end.microseconds) / 1_000_000 / duration))
        var times = [0.0]
        var values = [begin == 0 ? 1 : 0]
        if begin > 0 {
            times.append(begin)
            values.append(1)
        }
        if end < 1 {
            times.append(end)
            values.append(0)
        }
        if times.last != 1 {
            times.append(1)
            values.append(values.last ?? 0)
        }

        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = values.map { NSNumber(value: $0) }
        animation.keyTimes = times.map { NSNumber(value: $0) }
        animation.calculationMode = .discrete
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.duration = duration
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        return animation
    }
}
