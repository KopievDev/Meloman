import AVFoundation
import CoreMedia
import Foundation
import MelomanDomain

public enum AudioWaveformError: LocalizedError {
    case missingAudioTrack
    case readerFailed
    case invalidPCM

    public var errorDescription: String? {
        switch self {
        case .missingAudioTrack:
            "В исходном файле нет звуковой дорожки."
        case .readerFailed:
            "Не удалось прочитать аудио для волновой формы."
        case .invalidPCM:
            "Не удалось декодировать аудио для волновой формы."
        }
    }
}

/// Samples the original audio/video asset on a utility thread; no full-length
/// PCM recording is kept in memory. A1 is visualization only, not a new stem.
public enum AudioWaveformSampler {
    public static func sample(url: URL, duration: Timecode) async throws -> AudioWaveform {
        let worker = Task.detached(priority: .utility) {
            try await extract(url: url, duration: duration)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func extract(url: URL, duration: Timecode) async throws -> AudioWaveform {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw AudioWaveformError.missingAudioTrack }

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AudioWaveformError.readerFailed }

        var envelope = AudioWaveform(duration: duration)
        while reader.status == .reading {
            if Task.isCancelled {
                reader.cancelReading()
                throw CancellationError()
            }
            guard let buffer = output.copyNextSampleBuffer() else { break }
            try accumulate(buffer, into: &envelope)
        }
        guard reader.status == .completed else {
            throw reader.error ?? AudioWaveformError.readerFailed
        }
        return envelope
    }

    private static func accumulate(_ buffer: CMSampleBuffer, into envelope: inout AudioWaveform) throws {
        guard let format = CMSampleBufferGetFormatDescription(buffer),
              let description = CMAudioFormatDescriptionGetStreamBasicDescription(format),
              let block = CMSampleBufferGetDataBuffer(buffer)
        else { throw AudioWaveformError.invalidPCM }

        let channels = Int(description.pointee.mChannelsPerFrame)
        let length = CMBlockBufferGetDataLength(block)
        guard channels > 0, length > 0, length.isMultiple(of: MemoryLayout<Float>.size) else {
            throw AudioWaveformError.invalidPCM
        }
        var samples = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
        let code = samples.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(
                block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!
            )
        }
        guard code == noErr else { throw AudioWaveformError.invalidPCM }
        envelope.ingest(
            interleaved: samples,
            channels: channels,
            at: CMSampleBufferGetPresentationTimeStamp(buffer).seconds,
            sampleRate: description.pointee.mSampleRate
        )
    }
}
