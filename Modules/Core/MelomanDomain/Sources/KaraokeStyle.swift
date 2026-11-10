import Foundation

/// Safe, portable typefaces available on standard macOS installations.
/// PostScript names are shared by AppKit preview and Core Animation export.
public enum KaraokeFont: String, CaseIterable, Codable, Sendable {
    case helveticaBold
    case avenirDemiBold
    case georgiaBold
    case menloBold

    public var postScriptName: String {
        switch self {
        case .helveticaBold: "HelveticaNeue-Bold"
        case .avenirDemiBold: "AvenirNext-DemiBold"
        case .georgiaBold: "Georgia-Bold"
        case .menloBold: "Menlo-Bold"
        }
    }

    public var displayName: String {
        switch self {
        case .helveticaBold: "Классический"
        case .avenirDemiBold: "Современный"
        case .georgiaBold: "С засечками"
        case .menloBold: "Моноширинный"
        }
    }
}

/// Explicit sRGB bytes avoid serializing system/semantic NSColor objects.
public struct KaraokeRGB: Codable, Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = KaraokeRGB(red: 255, green: 255, blue: 255)
    public static let yellow = KaraokeRGB(red: 255, green: 215, blue: 0)
}

/// Karaoke title styling at a 1280 px reference video width.
/// The vertical position is measured from the bottom (0.0) to the top (1.0).
public struct KaraokeStyle: Codable, Equatable, Sendable {
    public var font: KaraokeFont
    public var fontSize: Double
    public var textColor: KaraokeRGB
    public var highlightColor: KaraokeRGB
    public var verticalPosition: Double

    public init(
        font: KaraokeFont = .helveticaBold,
        fontSize: Double = 56,
        textColor: KaraokeRGB = .white,
        highlightColor: KaraokeRGB = .yellow,
        verticalPosition: Double = 0.18
    ) {
        self.font = font
        self.fontSize = fontSize
        self.textColor = textColor
        self.highlightColor = highlightColor
        self.verticalPosition = verticalPosition
    }

    public func sanitized() -> KaraokeStyle {
        var copy = self
        copy.fontSize = fontSize.isFinite ? min(112, max(24, fontSize)) : 56
        copy.verticalPosition = verticalPosition.isFinite ? min(0.85, max(0.12, verticalPosition)) : 0.18
        return copy
    }
}
