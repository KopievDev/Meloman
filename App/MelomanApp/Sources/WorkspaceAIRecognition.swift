import AppKit
import KaraokeEngine
import MediaPipeline
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    @objc func recognizeLyrics(_: Any?) {
        guard !isBusy,
              let mediaID = selectedMediaID,
              let selected = project.media.first(where: { $0.id == mediaID }),
              let mediaURL = mediaURLs[mediaID]
        else { return }

        let existing = project.karaokeLines(for: mediaID)
        if !existing.isEmpty {
            let confirm = NSAlert()
            confirm.messageText = "Заменить существующий текст на AI-разметку?"
            confirm.informativeText = "Текущие слова и таймкоды заменятся после распознавания. " +
                "Изменение можно отменить через кнопку «Отменить»."
            confirm.addButton(withTitle: "Распознать и заменить")
            confirm.addButton(withTitle: "Отмена")
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
        }

        isBusy = true
        setBusyControls()
        statusLabel.stringValue = "AI: подготовка аудиодорожки…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            await performRecognition(mediaID: mediaID, asset: selected, mediaURL: mediaURL)
        }
    }

    func performRecognition(mediaID: UUID, asset: MediaAsset, mediaURL: URL) async {
        var temporaryAudio: URL?
        defer {
            if let temporaryAudio {
                try? FileManager.default.removeItem(at: temporaryAudio)
            }
            isBusy = false
            setBusyControls()
        }

        do {
            let source = try await TranscriptionAudioPreparer().prepare(
                source: mediaURL,
                kind: asset.kind
            )
            if asset.kind == .video {
                temporaryAudio = source
            }

            let words = try await speechRecognizer.recognize(audioAt: source)
            let lines = RecognizedLyricsBuilder.lines(from: words, duration: asset.duration)
            guard !lines.isEmpty else {
                showError("AI не обнаружил слов с корректными таймкодами. " +
                    "Попробуйте другой файл или ручную разметку.")
                return
            }

            editLyrics(lines, for: mediaID)
            if selectedMediaID == mediaID {
                selectedWordID = lines.first?.words.first?.id
                refreshKaraoke()
            }
            statusLabel.stringValue = "AI: \(words.count) слов распознано. Проверьте текст и сохраните проект."
        } catch {
            statusLabel.stringValue = "AI: ошибка распознавания"
            showError(error.localizedDescription)
        }
    }
}
