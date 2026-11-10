import Foundation

/// Deterministic GIF frame timing shared by preview and movie encoding.
public struct GIFPlaybackTiming: Equatable, Sendable {
    public let durations: [Double]
    public let totalDuration: Double

    public init(frameDurations: [Double]) {
        let normalized = frameDurations.map { duration in
            duration.isFinite && duration >= 0.02 ? duration : 0.1
        }
        durations = normalized
        totalDuration = normalized.reduce(0, +)
    }

    public func frameIndex(at seconds: Double) -> Int? {
        guard !durations.isEmpty, seconds.isFinite, totalDuration > 0 else { return nil }
        let elapsed = max(0, seconds).truncatingRemainder(dividingBy: totalDuration)
        var end = 0.0
        for (index, duration) in durations.enumerated() {
            end += duration
            if elapsed < end {
                return index
            }
        }
        return durations.indices.last
    }
}
