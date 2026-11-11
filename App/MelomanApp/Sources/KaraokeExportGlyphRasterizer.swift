import AppKit
import CoreGraphics
import CoreText
import KaraokeEngine

/// Render with the same CoreText baseline as KaraokeOverlayView.
///
/// CATextLayer positions single-line text using its own internal top inset,
/// which previously shifted exported lyrics upward relative to the preview.
@MainActor
enum KaraokeExportGlyphRasterizer {
    static let pixelScale: CGFloat = 1

    static func render(_ line: CTLine, geometry: KaraokeSubtitleGeometry) -> CGImage? {
        let pixelWidth = Int(ceil(geometry.size.width * pixelScale))
        let pixelHeight = Int(ceil(geometry.size.height * pixelScale))
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: info
        ) else { return nil }

        context.scaleBy(x: pixelScale, y: pixelScale)
        context.clear(CGRect(origin: .zero, size: geometry.size))
        context.setShouldAntialias(true)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: geometry.padding, y: geometry.baselineFromBottom)
        context.setShadow(
            offset: CGSize(width: 1, height: -2),
            blur: 5,
            color: NSColor.black.cgColor
        )
        CTLineDraw(line, context)
        return context.makeImage()
    }
}
