import AppKit
import AVFoundation
import LocalAI
import MediaPipeline
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    func makeVocalControls() -> NSView {
        let title = label("РАЗДЕЛЕНИЕ ВОКАЛА", size: 11, weight: .semibold, color: .secondaryLabelColor)
        useCleanVocals.state = .on
        useCleanVocals.toolTip = "При распознавании отделять вокал выбранной моделью"
        separationQuality.addItems(withTitles: [
            "Spleeter · быстрее",
            "Mel-Band RoFormer · качество",
            "BS-RoFormer · эксперимент",
        ])
        let executable = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Meloman/Engines/MLX/bin/mlx-audio-separator")
        separationQuality.selectItem(
            at: FileManager.default.isExecutableFile(atPath: executable.path) ? 1 : 0
        )
        separationQuality.target = self
        separationQuality.action = #selector(separationModelChanged(_:))

        syncLyricsButton.target = self
        syncLyricsButton.action = #selector(synchronizeKnownLyrics(_:))
        syncLyricsButton.toolTip = "Синхронизировать правильный текст с аудио, не изменяя слова"

        separateButton.target = self
        separateButton.action = #selector(separateCurrentVocals(_:))
        playVocalsButton.target = self
        playVocalsButton.action = #selector(previewVocals(_:))
        playInstrumentalButton.target = self
        playInstrumentalButton.action = #selector(previewInstrumental(_:))
        playOriginalButton.target = self
        playOriginalButton.action = #selector(previewOriginal(_:))

        let playback = NSStackView(views: [playVocalsButton, playInstrumentalButton, playOriginalButton])
        playback.distribution = .fillEqually
        playback.spacing = 3
        let stack = NSStackView(views: [
            title, separationQuality, useCleanVocals, separateButton, syncLyricsButton, playback,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        for view in [separationQuality, separateButton, syncLyricsButton, playback] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        updateStemButtons()
        return stack
    }

    func updateStemButtons() {
        separateButton.isEnabled = !isBusy && selectedMediaID != nil
        syncLyricsButton.isEnabled = !isBusy && selectedMediaID.map {
            !project.karaokeLines(for: $0).isEmpty
        } == true
        let available = !isBusy && selectedMediaID.flatMap { stemsByMediaID[$0] } != nil
        playVocalsButton.isEnabled = available
        playInstrumentalButton.isEnabled = available
        playOriginalButton.isEnabled = !isBusy && selectedMediaID != nil
        useCleanVocals.isEnabled = !isBusy
        separationQuality.isEnabled = !isBusy
    }

    @objc func separationModelChanged(_: Any?) {
        guard selectedMediaID != nil else { return }
        stemsByMediaID.removeAll()
        loadSelectedMedia()
        updateStemButtons()
    }

    func separateAudio(audioURL: URL, originalURL: URL) async throws -> VocalStems {
        switch separationQuality.indexOfSelectedItem {
        case 1:
            try await roFormerSeparator.separate(
                audioURL: audioURL,
                originalURL: originalURL,
                model: .zfTurbo
            )
        case 2:
            try await roFormerSeparator.separate(
                audioURL: audioURL,
                originalURL: originalURL,
                model: .bsRoFormer
            )
        default:
            try await vocalSeparator.separate(audioURL: audioURL, originalURL: originalURL)
        }
    }

    @objc func separateCurrentVocals(_: Any?) {
        guard !isBusy,
              let id = selectedMediaID,
              let asset = project.media.first(where: { $0.id == id }),
              let url = mediaURLs[id]
        else { return }

        isBusy = true
        setBusyControls()
        displayAIProgress(title: "Подготовка вокала", detail: "Подготовка дорожек для Core ML")
        Task { [weak self] in
            guard let self else { return }
            defer {
                isBusy = false
                setBusyControls()
            }
            do {
                var temporary: URL?
                defer {
                    if let temporary {
                        try? FileManager.default.removeItem(at: temporary)
                    }
                }
                let input = try await TranscriptionAudioPreparer().prepare(
                    source: url,
                    kind: asset.kind,
                    onProgress: { [weak self] fraction in
                        self?.displayAIProgress(
                            title: "Извлечение звука",
                            detail: "Подготовка звуковой дорожки",
                            fraction: fraction
                        )
                    }
                )
                if asset.kind == .video {
                    temporary = input
                }
                let stems = try await separateAudio(audioURL: input, originalURL: url)
                stemsByMediaID[id] = stems
                statusLabel.stringValue = stems.wasCached
                    ? "Дорожки найдены в кеше" : "Вокал и минусовка готовы"
                updateStemButtons()
            } catch {
                displayAIProgress(
                    title: "Ошибка отделения вокала",
                    detail: error.localizedDescription,
                    active: false
                )
                showError(error.localizedDescription)
            }
        }
    }

    @objc func previewVocals(_: Any?) {
        previewStem(\.vocals, title: "Вокальная дорожка")
    }

    @objc func previewInstrumental(_: Any?) {
        previewStem(\.instrumental, title: "Инструментальная дорожка")
    }

    @objc func previewOriginal(_: Any?) {
        loadSelectedMedia()
    }

    private func previewStem(_ key: KeyPath<VocalStems, URL>, title: String) {
        guard !isBusy, let id = selectedMediaID, let stems = stemsByMediaID[id] else { return }
        player.pause()
        player.replaceCurrentItem(with: AVPlayerItem(url: stems[keyPath: key]))
        previewHint.stringValue = title
        updatePlaybackUI()
        playButton.isEnabled = true
        seekSlider.isEnabled = true
    }
}
