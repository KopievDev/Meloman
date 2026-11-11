import CoreGraphics
import Foundation

/// Places an offscreen CoreText line exactly on the preview's glyph baseline.
///
/// CGImages contain padding for the glyph shadow. CALayer's position is its
/// visual centre, not the CoreText baseline, so that inset must be compensated.
public struct KaraokeSubtitleGeometry: Equatable {
    public let textWidth: CGFloat
    public let size: CGSize
    public let padding: CGFloat
    public let baselineFromBottom: CGFloat

    public init(textWidth: CGFloat, ascent: CGFloat, descent: CGFloat, padding: CGFloat = 12) {
        self.textWidth = textWidth
        self.padding = padding
        baselineFromBottom = padding + descent
        size = CGSize(
            width: ceil(textWidth + padding * 2),
            height: ceil(ascent + descent + padding * 2)
        )
    }

    public func layerCenter(in canvas: CGSize, baseline: CGFloat, scale: CGFloat) -> CGPoint {
        let textLeft = max(18, (canvas.width - textWidth * scale) / 2)
        return CGPoint(
            x: textLeft + (size.width / 2 - padding) * scale,
            y: baseline + (size.height / 2 - baselineFromBottom) * scale
        )
    }
}
