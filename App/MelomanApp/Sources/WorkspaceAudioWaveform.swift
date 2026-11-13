import AppKit
import AVFoundation
import MediaPipeline
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    /// Decode once per imported media UUID. Switching or closing media cancels
    /// its old task and never lets a stale result replace the selected waveform.
    func refreshAudioWaveform() {
        waveformTask?.cancel()
        waveformTask = nil
        waveformStrip.waveform = nil

        guard let media = project.media.first(where: { $0.id == selectedMediaID }),
              let url = mediaURLs[media.id]
        else {
            waveformStrip.duration = .zero
            waveformStrip.message = "Выберите аудио или видео"
            return
        }

        waveformStrip.duration = media.duration
        waveformStrip.setFrameSize(NSSize(width: timelineWidth(for: media.duration), height: 32))
        if let cached = cachedWaveforms[media.id] {
            waveformStrip.waveform = cached
            return
        }

        waveformStrip.message = "Загружаем звуковую волну…"
        waveformTask = Task { [weak self] in
            do {
                let result = try await AudioWaveformSampler.sample(url: url, duration: media.duration)
                guard !Task.isCancelled, let self, self.selectedMediaID == media.id else { return }
                cachedWaveforms[media.id] = result
                waveformStrip.waveform = result
            } catch {
                guard !Task.isCancelled, let self, self.selectedMediaID == media.id else { return }
                waveformStrip.message = error.localizedDescription
            }
        }
    }

    func seekFromWaveform(to time: Timecode) {
        let target = CMTime(value: time.microseconds, timescale: 1_000_000)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        syncBackgroundVideo(to: target.seconds, forceSeek: true)
        updatePlaybackUI()
    }
}
