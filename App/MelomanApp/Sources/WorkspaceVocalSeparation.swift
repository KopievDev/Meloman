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
        useCleanVocals.toolTip = "При распознавании сначала отделять голос нейросетью Core ML"

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
        let stack = NSStackView(views: [title, useCleanVocals, separateButton, playback])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        for view in [separateButton, playback] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        updateStemButtons()
        return stack
    }

    func updateStemButtons() {
        separateButton.isEnabled = !isBusy && selectedMediaID != nil
        let available = !isBusy && selectedMediaID.flatMap { stemsByMediaID[$0] } != nil
        playVocalsButton.isEnabled = available
        playInstrumentalButton.isEnabled = available
        playOriginalButton.isEnabled = !isBusy && selectedMediaID != nil
        useCleanVocals.isEnabled = !isBusy
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
                let stems = try await vocalSeparator.separate(audioURL: input, originalURL: url)
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
