import Foundation
import MelomanDomain
import XCTest

final class AudioWaveformTests: XCTestCase {
    func testWaveformPeakBucketsTrackMediaTimeAcrossChunks() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        var waveform = AudioWaveform(duration: duration, binsPerSecond: 4)
        waveform.ingest(interleaved: [0.1, -0.8, 0.4, 0.2], channels: 2, at: 0, sampleRate: 4)
        waveform.ingest(interleaved: [0.7, 0.3, 0.2, 0.5], channels: 2, at: 0.5, sampleRate: 4)
        XCTAssertEqual(waveform.peaks, [0.8, 0.4, 0.7, 0.5])
    }

    func testWaveformPeaksIgnoreInvalidSamplesAndTimeBoundaries() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 1_000_000))
        var waveform = AudioWaveform(duration: duration, binsPerSecond: 2)
        waveform.ingest(interleaved: [.nan, .infinity, -0.4, 8], channels: 2, at: 0, sampleRate: 2)
        waveform.ingest(interleaved: [0.9, 0.8], channels: 1, at: 1, sampleRate: 2)
        waveform.ingest(interleaved: [0.9], channels: 0, at: 0, sampleRate: 2)
        XCTAssertEqual(waveform.peaks, [0, 1])
    }

    func testWaveformCapsPeakCountForVeryLongMedia() throws {
        let duration = try XCTUnwrap(Timecode(microseconds: 50_000_000_000))
        let waveform = AudioWaveform(duration: duration, binsPerSecond: 80)
        XCTAssertEqual(waveform.peaks.count, 300_000)
    }
}
