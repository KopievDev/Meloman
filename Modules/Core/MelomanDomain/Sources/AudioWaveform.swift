import Foundation

/// Fixed-duration peak envelope for the A1 timeline. Bins are derived from
/// media timestamps, not read-buffer boundaries, so chunk size cannot shift
/// audio peaks relative to karaoke word timecodes.
public struct AudioWaveform: Equatable, Sendable {
    public let duration: Timecode
    public private(set) var peaks: [Float]

    public init(duration: Timecode, binsPerSecond: Double = 40) {
        self.duration = duration
        let seconds = Double(duration.microseconds) / 1_000_000
        let requested = seconds * max(1, binsPerSecond)
        let count = max(1, Int(min(300_000, ceil(requested))))
        peaks = [Float](repeating: 0, count: count)
    }

    /// Accumulate the maximum absolute channel amplitude in each time bucket.
    /// Samples outside the media timeline and non-finite values are ignored.
    public mutating func ingest(
        interleaved samples: [Float],
        channels: Int,
        at timestamp: Double,
        sampleRate: Double
    ) {
        guard channels > 0, sampleRate > 0, sampleRate.isFinite,
              timestamp.isFinite, !peaks.isEmpty, duration.microseconds > 0
        else { return }

        let seconds = Double(duration.microseconds) / 1_000_000
        let frames = samples.count / channels
        for frame in 0 ..< frames {
            let time = timestamp + Double(frame) / sampleRate
            guard time >= 0, time < seconds else { continue }
            let index = min(peaks.count - 1, Int(time / seconds * Double(peaks.count)))
            let start = frame * channels
            var amplitude: Float = 0
            for channel in 0 ..< channels {
                let value = abs(samples[start + channel])
                if value.isFinite {
                    amplitude = max(amplitude, min(1, value))
                }
            }
            peaks[index] = max(peaks[index], amplitude)
        }
    }
}
