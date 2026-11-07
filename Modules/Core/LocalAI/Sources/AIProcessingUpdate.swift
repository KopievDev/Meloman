import Foundation

/// UI-agnostic progress event from the local ASR adapter.
/// A nil fraction means that the current operation has no measurable completion ratio.
public struct AIProcessingUpdate: Sendable {
    public let title: String
    public let detail: String
    public let fraction: Double?
    public let isActive: Bool

    public init(title: String, detail: String, fraction: Double? = nil, isActive: Bool = true) {
        self.title = title
        self.detail = detail
        self.fraction = fraction
        self.isActive = isActive
    }
}
