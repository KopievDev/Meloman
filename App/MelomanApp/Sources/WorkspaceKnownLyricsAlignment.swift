import AppKit
import KaraokeEngine
import LocalAI
import MediaPipeline
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    @objc func synchronizeKnownLyrics(_: Any?) {
        guard !isBusy,
              let mediaID = selectedMediaID,
              let media = project.media.first(where: { $0.id == mediaID }),
              let sourceURL = mediaURLs[mediaID]
        else { return }

        let reference = project.karaokeLines(for: mediaID)
        guard !reference.flatMap(\.words).isEmpty else {
            showError("Сначала вставьте правильный текст через кнопку «Текст песни».")
            return
        }

        let confirm = NSAlert()
        confirm.messageText = "Синхронизировать готовый текст?"
        confirm.informativeText = "Все исходные слова и строки останутся без изменений. " +
            "Акустическая модель найдёт таймкоды. Начало слов может быть точнее конца; " +
            "неточные участки будут отмечены оранжевым."
        confirm.addButton(withTitle: "Синхронизировать")
        confirm.addButton(withTitle: "Отмена")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        isBusy = true
        setBusyControls()
        Task { [weak self] in
            await self?.performLyricsAlignment(
                mediaID: mediaID,
                media: media,
                sourceURL: sourceURL,
                reference: reference
            )
        }
    }

    func performLyricsAlignment(
        mediaID: UUID,
        media: MediaAsset,
        sourceURL: URL,
        reference: [LyricLine]
    ) async {
        var temporaryAudio: URL?
        defer {
            if let temporaryAudio {
                try? FileManager.default.removeItem(at: temporaryAudio)
            }
            isBusy = false
            setBusyControls()
        }

        do {
            displayAIProgress(title: "Подготовка песни", detail: "Подготовка аудиодорожки")
            let source = try await TranscriptionAudioPreparer().prepare(
                source: sourceURL,
                kind: media.kind,
                onProgress: { [weak self] fraction in
                    self?.displayAIProgress(
                        title: "Подготовка песни",
                        detail: "Извлечение аудио из клипа",
                        fraction: fraction
                    )
                }
            )
            if media.kind == .video {
                temporaryAudio = source
            }

            let audio = try await alignmentAudio(source: source, original: sourceURL, mediaID: mediaID)
            let result = try await lyricsCTCAligner.align(audioURL: audio, lines: reference)
            guard project.karaokeLines(for: mediaID) == reference else {
                throw LyricsAlignmentWorkflowError.referenceChanged
            }
            applyAlignedLyrics(result, to: reference, mediaID: mediaID, duration: media.duration)
        } catch {
            displayAIProgress(
                title: "Синхронизация не завершена",
                detail: error.localizedDescription,
                active: false
            )
            showError(error.localizedDescription)
        }
    }

    func alignmentAudio(source: URL, original: URL, mediaID: UUID) async throws -> URL {
        guard useCleanVocals.state == .on else { return source }
        let stems = try await separateAudio(audioURL: source, originalURL: original)
        stemsByMediaID[mediaID] = stems
        updateStemButtons()
        return stems.vocals
    }

    func applyAlignedLyrics(
        _ alignment: AcousticLyricsAlignment,
        to reference: [LyricLine],
        mediaID: UUID,
        duration: Timecode
    ) {
        let applied = LyricsAlignmentApplier.apply(alignment, to: reference, duration: duration)
        guard applied.updatedWords > 0 else {
            showError("CTC не смог привязать слова. Исходный текст и таймкоды сохранены.")
            return
        }

        let total = reference.reduce(0) { $0 + $1.words.count }
        let needsReview = applied.updatedWords * 10 < total * 7 ||
            applied.lowConfidenceWords * 3 > applied.updatedWords
        guard !needsReview || confirmWeakAlignment(applied, total: total) else {
            displayAIProgress(title: "Разметка не применена", detail: "Исходные таймкоды сохранены", active: false)
            return
        }

        editLyrics(applied.lines, for: mediaID)
        if selectedMediaID == mediaID {
            refreshKaraoke()
        }
        displayAIProgress(
            title: "Таймкоды применены",
            detail: "\(applied.updatedWords) из \(total) слов; оранжевые блоки проверьте вручную",
            active: false
        )
        statusLabel.stringValue = "Текст сохранён без изменений. Не забудьте сохранить проект."
    }

    func confirmWeakAlignment(_ applied: AppliedLyricsAlignment, total: Int) -> Bool {
        let warning = NSAlert()
        warning.messageText = "Некоторые таймкоды требуют проверки"
        warning.informativeText = "Синхронизировано \(applied.updatedWords) из \(total) слов. " +
            "Низкая уверенность у \(applied.lowConfidenceWords) слов. " +
            "Остальные сохранят прежние времена. Применить результат?"
        warning.addButton(withTitle: "Применить и проверить")
        warning.addButton(withTitle: "Не менять")
        return warning.runModal() == .alertFirstButtonReturn
    }
}

enum LyricsAlignmentWorkflowError: LocalizedError {
    case referenceChanged

    var errorDescription: String? {
        "Текст был изменён во время синхронизации. Повторите обработку с актуальной версией."
    }
}
