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

    static func pronunciationFont(for style: KaraokeStyle, width: CGFloat) -> CTFont {
        let base = font(for: style, width: width)
        let points = max(9, CGFloat(CTFontGetSize(base)) * 0.55)
        return CTFontCreateWithName(style.sanitized().font.postScriptName as CFString, points, nil)
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

    /// Keep the two fixed screen slots visible even with low subtitle positions.
    /// Active highlighting can switch slots without physically moving text.
    static func baseline(
        for slot: KaraokeDisplaySlot,
        style: KaraokeStyle,
        size: CGSize,
        fontSize: CGFloat,
        pronunciationEnabled: Bool = false
    ) -> CGFloat {
        let spacing = fontSize * (pronunciationEnabled ? 2.1 : 1.45)
        let bottomInset = max(10, fontSize * (pronunciationEnabled ? 1.36 : 0.95))
        let extra = pronunciationEnabled ? fontSize * 0.68 : 0
        let upperLimit = max(bottomInset + spacing + extra, size.height - fontSize * 1.2)
        let preferred = baseline(for: style, size: size, fontSize: fontSize)
        let upper = min(upperLimit, max(bottomInset + spacing + extra, preferred))
        return slot == .upper ? upper : upper - spacing
    }

    static func pronunciationBaseline(
        for slot: KaraokeDisplaySlot,
        style: KaraokeStyle,
        size: CGSize,
        mainFontSize: CGFloat
    ) -> CGFloat {
        baseline(
            for: slot,
            style: style,
            size: size,
            fontSize: mainFontSize,
            pronunciationEnabled: true
        ) - mainFontSize * 0.68
    }

    static func baseline(for style: KaraokeStyle, size: CGSize, fontSize: CGFloat) -> CGFloat {
        let position = CGFloat(style.sanitized().verticalPosition)
        let inset = fontSize * 0.85
        return max(inset, min(size.height - inset, size.height * position))
    }
}
