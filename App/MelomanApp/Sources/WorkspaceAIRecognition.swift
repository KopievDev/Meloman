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
        displayAIProgress(
            title: "Шаг 1/3 · Подготовка аудио",
            detail: selected.kind == .video ? "Извлечение звука из видео" : "Аудиофайл готов"
        )

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
                kind: asset.kind,
                onProgress: { [weak self] fraction in
                    self?.displayAIProgress(
                        title: "Шаг 1/3 · Подготовка аудио",
                        detail: fraction.map { "Извлечено \(Int($0 * 100))% звуковой дорожки" }
                            ?? "Извлечение звуковой дорожки из видео",
                        fraction: fraction
                    )
                }
            )
            if asset.kind == .video {
                temporaryAudio = source
            }

            let language: String? = switch recognitionLanguage.indexOfSelectedItem {
            case 1: "ru"
            case 2: "en"
            default: nil
            }
            let words = try await speechRecognizer.recognize(audioAt: source, language: language)
            displayAIProgress(title: "Шаг 3/3 · Разметка караоке", detail: "Формирование строк и слов")
            let lines = RecognizedLyricsBuilder.lines(from: words, duration: asset.duration)
            guard !lines.isEmpty else {
                displayAIProgress(title: "Нет распознанных слов", detail: "Проверьте файл", active: false)
                showError("AI не обнаружил слов с корректными таймкодами. " +
                    "Попробуйте другой файл или ручную разметку.")
                return
            }

            let sparse = words.count < max(5, Int(Double(asset.duration.microseconds) / 20_000_000))
            if sparse {
                let warning = NSAlert()
                warning.messageText = "Найдено слишком мало слов"
                warning.informativeText = "Whisper распознал только \(words.count) слов. " +
                    "Не рекомендуем заменять полный текст. " +
                    "Для песен лучше вставить известный текст, а затем выполнить точную синхронизацию."
                warning.addButton(withTitle: "Не заменять текст")
                warning.addButton(withTitle: "Сохранить частичную разметку")
                if warning.runModal() != .alertSecondButtonReturn {
                    displayAIProgress(
                        title: "Разметка не заменена",
                        detail: "Вставьте текст через «Текст песни»",
                        active: false
                    )
                    return
                }
            }

            editLyrics(lines, for: mediaID)
            if selectedMediaID == mediaID {
                selectedWordID = lines.first?.words.first?.id
                refreshKaraoke()
            }
            displayAIProgress(
                title: "Готово — \(words.count) слов",
                detail: "Проверьте таймкоды и сохраните проект",
                active: false
            )
            statusLabel.stringValue = "AI: разметка создана"
        } catch {
            statusLabel.stringValue = "AI: ошибка распознавания"
            displayAIProgress(title: "Ошибка распознавания", detail: error.localizedDescription, active: false)
            showError(error.localizedDescription)
        }
    }
}
