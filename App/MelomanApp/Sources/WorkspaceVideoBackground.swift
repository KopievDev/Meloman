import AppKit
import AVFoundation
import MelomanDomain
import UniformTypeIdentifiers

@MainActor
extension WorkspaceViewController {
    @objc func selectBackgroundVideo(_: Any?) {
        guard !isBusy,
              let id = selectedMediaID,
              project.media.first(where: { $0.id == id })?.kind == .audio
        else { return }

        let panel = NSOpenPanel()
        panel.message = "Выберите MP4/MOV для фона (видеозвук не используется)"
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie] +
            (UTType(filenameExtension: "m4v").map { [$0] } ?? [])
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) else {
            showError("Поддерживаются только MP4, MOV и M4V.")
            return
        }

        Task { @MainActor [weak self] in
            do {
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration).seconds
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard duration.isFinite, duration >= 0.5, !tracks.isEmpty else {
                    self?.showError("Видеофон должен содержать видео длительностью от 0,5 секунды.")
                    return
                }
                guard let self, self.selectedMediaID == id else { return }
                project.setBackgroundVideo(
                    MediaBackgroundVideo(mediaID: id, fileExtension: url.pathExtension),
                    for: id
                )
                project.setBackgroundImage(nil, for: id)
                backgroundVideoURLs[id] = url
                backgroundURLs.removeValue(forKey: id)
                refreshBackgroundPreview()
                refreshBackgroundControls()
                statusLabel.stringValue = "Видеофон обновлён. Сохраните проект."
            } catch {
                self?.showError("Ошибка видеофона: \(error.localizedDescription)")
            }
        }
    }

    func configureBackgroundVideo(_ url: URL?) {
        backgroundDurationTask?.cancel()
        backgroundDurationTask = nil
        backgroundPlayer.pause()
        backgroundPlayer.replaceCurrentItem(with: url.map { AVPlayerItem(url: $0) })
        backgroundPlayer.isMuted = true
        activeBackgroundVideoURL = url
        backgroundVideoDuration = 0
        preview.backgroundVideoLayer.isHidden = url == nil

        guard let url else { return }
        let asset = AVURLAsset(url: url)
        backgroundDurationTask = Task { @MainActor [weak self] in
            do {
                let duration = try await asset.load(.duration).seconds
                guard let self, self.activeBackgroundVideoURL == url, !Task.isCancelled else { return }
                guard duration.isFinite, duration >= 0.5 else { return }
                backgroundVideoDuration = duration
                let now = player.currentTime().seconds
                syncBackgroundVideo(to: now.isFinite ? now : 0, forceSeek: true)
            } catch {
                // The original audio remains playable if an external video becomes unavailable.
            }
        }
    }

    func syncBackgroundVideo(to seconds: Double, forceSeek: Bool = false) {
        guard activeBackgroundVideoURL != nil,
              backgroundVideoDuration >= 0.5,
              seconds.isFinite
        else {
            backgroundPlayer.pause()
            return
        }

        let target = max(0, seconds).truncatingRemainder(dividingBy: backgroundVideoDuration)
        let current = backgroundPlayer.currentTime().seconds
        if forceSeek || !current.isFinite || abs(current - target) > 0.35 {
            backgroundPlayer.seek(
                to: CMTime(seconds: target, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
        if player.rate > 0 {
            if backgroundPlayer.rate == 0 {
                backgroundPlayer.play()
            }
        } else {
            backgroundPlayer.pause()
        }
    }
}
