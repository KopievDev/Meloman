import Foundation

/// Neutral ASR adapter result. Model-specific types never reach the project or editor.
public struct RecognizedWord: Equatable, Sendable {
    public let text: String
    public let startSeconds: Double
    public let endSeconds: Double
    public let segment: Int

    public init(text: String, startSeconds: Double, endSeconds: Double, segment: Int) {
        self.text = text
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.segment = segment
    }
}
