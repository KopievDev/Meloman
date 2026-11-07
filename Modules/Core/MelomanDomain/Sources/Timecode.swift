import Foundation

/// A nonnegative timeline timestamp in microseconds.
/// AVFoundation/Core Media conversion must happen outside the Domain module.
public struct Timecode: Codable, Comparable, Hashable, Sendable {
    public let microseconds: Int64

    public static let zero = Timecode(uncheckedMicroseconds: 0)

    public init?(microseconds: Int64) {
        guard microseconds >= 0 else { return nil }
        self.microseconds = microseconds
    }

    private init(uncheckedMicroseconds: Int64) {
        microseconds = uncheckedMicroseconds
    }

    public static func < (lhs: Timecode, rhs: Timecode) -> Bool {
        lhs.microseconds < rhs.microseconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int64.self)
        guard value >= 0 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Timecode cannot be negative."
            )
        }
        microseconds = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(microseconds)
    }
}
