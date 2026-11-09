import Foundation

/// Exact word ID and acoustic timestamps produced by the optional local aligner.
/// The supplied reference text is never replaced by an ASR hypothesis.
public struct AcousticWordTiming: Codable, Equatable, Sendable {
    public let id: UUID
    public let startSeconds: Double
    public let endSeconds: Double
    public let confidence: Double

    public init(id: UUID, startSeconds: Double, endSeconds: Double, confidence: Double) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.confidence = confidence
    }
}

public struct AcousticLyricsAlignment: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let aligned: [AcousticWordTiming]
    public let unresolved: [UUID]

    public init(schemaVersion: Int = 1, aligned: [AcousticWordTiming], unresolved: [UUID]) {
        self.schemaVersion = schemaVersion
        self.aligned = aligned
        self.unresolved = unresolved
    }
}
