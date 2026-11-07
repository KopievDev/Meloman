import AppKit
import AVFoundation
import MelomanDomain
import ProjectStore
import UniformTypeIdentifiers

@MainActor
extension WorkspaceViewController {
    @objc func importMedia(_: Any?) {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.message = "Выберите музыкальные файлы или видеоклипы"
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ["mp3", "wav", "m4a", "aif", "aiff", "mp4", "mov", "m4v"]
            .compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK else { return }
        addMedia(panel.urls)
    }

    func addMedia(_ urls: [URL]) {
        guard !isBusy else { return }
        isBusy = true
        setBusyControls()
        statusLabel.stringValue = "Импорт медиа…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            var failures: [String] = []

            for url in urls {
                do {
                    let asset = try await mediaImporter.inspect(url)
                    project.media.append(asset)
                    mediaURLs[asset.id] = url
                    let clip = TimelineClip(start: .zero, duration: asset.duration, mediaID: asset.id)
                    project.tracks.append(
                        TimelineTrack(kind: asset.kind == .video ? .video : .audio, clips: [clip])
                    )
                    if selectedMediaID == nil {
                        selectedMediaID = asset.id
                    }
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            refreshMediaList()
            loadSelectedMedia()
            isBusy = false
            setBusyControls()

            if failures.isEmpty {
                statusLabel.stringValue = "Медиа добавлено: \(urls.count)"
            } else {
                statusLabel.stringValue = "Не удалось импортировать: \(failures.count)"
                showError(failures.joined(separator: "\n"))
            }
        }
    }

    @objc func selectMedia(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue,
              let id = UUID(uuidString: value)
        else { return }
        selectedMediaID = id
        selectedWordID = nil
        loadSelectedMedia()
        refreshMediaList()
    }

    func loadSelectedMedia() {
        player.pause()
        guard let selected = project.media.first(where: { $0.id == selectedMediaID }),
              let url = mediaURLs[selected.id]
        else {
            player.replaceCurrentItem(with: nil)
            previewHint.stringValue = "Импортируйте аудио или видео"
            playButton.isEnabled = false
            seekSlider.isEnabled = false
            inspectorInfo.stringValue = "Выберите файл в медиатеке"
            refreshKaraoke()
            updatePlaybackUI()
            return
        }

        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        previewHint.stringValue = selected.kind == .audio ? "♫  \(selected.name)" : ""
        playButton.isEnabled = true
        seekSlider.isEnabled = true
        inspectorInfo.stringValue = [
            selected.name,
            "",
            "Тип: \(selected.kind == .audio ? "Аудио" : "Видео")",
            "Длительность: \(formatTime(Double(selected.duration.microseconds) / 1_000_000))",
            "",
            "Источник сохранится внутри проекта .meloman.",
        ].joined(separator: "\n")
        timelineInfo.stringValue = "Выбран: \(selected.name)"
        refreshKaraoke()
        updatePlaybackUI()
    }

    func refreshMediaList() {
        for item in mediaStack.arrangedSubviews {
            mediaStack.removeArrangedSubview(item)
            item.removeFromSuperview()
        }

        if project.media.isEmpty {
            let empty = NSTextField(labelWithString: "Перетащите сюда MP3 или MP4")
            empty.textColor = .secondaryLabelColor
            empty.maximumNumberOfLines = 2
            empty.lineBreakMode = .byWordWrapping
            empty.frame.size.width = 190
            mediaStack.addArrangedSubview(empty)
        } else {
            for asset in project.media {
                let prefix = asset.kind == .audio ? "♫" : "▣"
                let button = NSButton(
                    title: "\(prefix)  \(asset.name)",
                    target: self,
                    action: #selector(selectMedia(_:))
                )
                button.identifier = NSUserInterfaceItemIdentifier(asset.id.uuidString)
                button.isBordered = asset.id == selectedMediaID
                button.alignment = .left
                button.toolTip = asset.name
                button.widthAnchor.constraint(equalToConstant: 195).isActive = true
                mediaStack.addArrangedSubview(button)
            }
        }

        mediaStack.frame = NSRect(
            x: 0,
            y: 0,
            width: 215,
            height: max(100, CGFloat(project.media.count + 1) * 42)
        )
    }

    @objc func togglePlayback(_: Any?) {
        guard player.currentItem != nil else { return }
        if player.rate == 0 {
            player.play()
        } else {
            player.pause()
        }
        updatePlaybackUI()
    }

    @objc func seek(_ sender: NSSlider) {
        guard let selected = project.media.first(where: { $0.id == selectedMediaID }) else { return }
        let duration = Double(selected.duration.microseconds) / 1_000_000
        let time = CMTime(seconds: sender.doubleValue * duration, preferredTimescale: 1_000_000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        updatePlaybackUI()
    }

    func updatePlaybackUI() {
        let current = player.currentTime().seconds
        let duration = project.media.first(where: { $0.id == selectedMediaID })
            .map { Double($0.duration.microseconds) / 1_000_000 } ?? 0
        let safeTime = current.isFinite ? max(0, current) : 0
        let position = duration > 0 ? min(1, safeTime / duration) : 0
        seekSlider.doubleValue = position
        timeLabel.stringValue = "\(formatTime(safeTime)) / \(formatTime(duration))"
        playButton.title = player.rate == 0 ? "▶" : "❚❚"
        refreshKaraokePlayhead(safeTime)
    }

    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let value = Int(seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    func setBusyControls() {
        importButton.isEnabled = !isBusy
        openButton.isEnabled = !isBusy
        saveButton.isEnabled = !isBusy
        karaokeButton.isEnabled = !isBusy && selectedMediaID != nil
        recognizeButton.isEnabled = !isBusy && selectedMediaID != nil
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Meloman"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
