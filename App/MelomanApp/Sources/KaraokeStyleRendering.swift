import AppKit
import CoreText
import KaraokeEngine
import MelomanDomain

/// Shared style-to-pixels math for interactive preview and offline MP4 export.
@MainActor
enum KaraokeStyleRendering {
    static func font(for style: KaraokeStyle, width: CGFloat) -> CTFont {
        let safe = style.sanitized()
        let points = max(10, CGFloat(safe.fontSize) * max(1, width) / 1280)
        return CTFontCreateWithName(safe.font.postScriptName as CFString, points, nil)
    }

    static func color(_ value: KaraokeRGB) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(value.red) / 255,
            green: CGFloat(value.green) / 255,
            blue: CGFloat(value.blue) / 255,
            alpha: 1
        )
    }

    static func rgb(_ value: NSColor) -> KaraokeRGB {
        let color = value.usingColorSpace(.deviceRGB) ?? .white
        func component(_ amount: CGFloat) -> UInt8 {
            UInt8(max(0, min(255, Int((amount * 255).rounded()))))
        }
        return KaraokeRGB(
            red: component(color.redComponent),
            green: component(color.greenComponent),
            blue: component(color.blueComponent)
        )
    }

    /// Keep both rows inside the canvas, even with low subtitle positions.
    /// The current line is on top; the next line is prepared underneath.
    static func baseline(
        for row: KaraokeDisplayRow,
        style: KaraokeStyle,
        size: CGSize,
        fontSize: CGFloat
    ) -> CGFloat {
        let spacing = fontSize * 1.45
        let bottomInset = max(10, fontSize * 0.95)
        let upperLimit = max(bottomInset + spacing, size.height - fontSize * 1.2)
        let preferred = baseline(for: style, size: size, fontSize: fontSize)
        let upper = min(upperLimit, max(bottomInset + spacing, preferred))
        return row == .current ? upper : upper - spacing
    }

    static func baseline(for style: KaraokeStyle, size: CGSize, fontSize: CGFloat) -> CGFloat {
        let position = CGFloat(style.sanitized().verticalPosition)
        let inset = fontSize * 0.85
        return max(inset, min(size.height - inset, size.height * position))
    }
}
