import AppKit
import MediaPipeline
import MelomanDomain
import UniformTypeIdentifiers

@MainActor
extension WorkspaceViewController {
    @objc func exportKaraokeVideo(_: Any?) {
        guard !isBusy,
              let id = selectedMediaID,
              let asset = project.media.first(where: { $0.id == id }),
              let source = mediaURLs[id]
        else { return }

        let lyrics = project.karaokeLines(for: id)
        guard !lyrics.flatMap(\.words).isEmpty else {
            showError("Для экспорта сначала добавьте текст и таймкоды песни.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + "-karaoke.mp4"
        panel.message = "Экспортировать выбранный файл с пословной подсветкой в MP4"

        let instrumentalCheck = NSButton(
            checkboxWithTitle: "Заменить оригинальный звук минусовкой (убрать вокал)",
            target: nil,
            action: nil
        )
        instrumentalCheck.frame = NSRect(x: 0, y: 0, width: 370, height: 32)
        instrumentalCheck.state = .off
        panel.accessoryView = instrumentalCheck
        guard panel.runModal() == .OK, let output = panel.url else { return }

        isBusy = true
        setBusyControls()
        displayAIProgress(title: "Экспорт караоке", detail: "Подготовка MP4")
        Task { [weak self] in
            await self?.performKaraokeExport(
                asset: asset,
                source: source,
                mediaID: id,
                lyrics: lyrics,
                instrumental: instrumentalCheck.state == .on,
                destination: output
            )
        }
    }

    func performKaraokeExport(
        asset: MediaAsset,
        source: URL,
        mediaID: UUID,
        lyrics: [LyricLine],
        instrumental: Bool,
        destination: URL
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
            let audioURL: URL?
            if instrumental {
                audioURL = try await prepareInstrumental(
                    asset: asset,
                    source: source,
                    mediaID: mediaID,
                    temporaryAudio: &temporaryAudio
                )
            } else {
                audioURL = nil
            }

            movieExporter.onProgress = { [weak self] title, detail, fraction in
                self?.displayAIProgress(title: title, detail: detail, fraction: fraction)
            }
            try await movieExporter.export(
                source: source,
                kind: asset.kind,
                duration: asset.duration,
                lyrics: lyrics,
                instrumental: audioURL,
                to: destination
            )
            displayAIProgress(
                title: "Экспорт готов",
                detail: "Создан файл \(destination.lastPathComponent)",
                active: false
            )
            statusLabel.stringValue = "Готовый MP4: \(destination.lastPathComponent)"
        } catch {
            displayAIProgress(title: "Экспорт не удался", detail: error.localizedDescription, active: false)
            showError("Ошибка экспорта MP4: \(error.localizedDescription)")
        }
    }

    private func prepareInstrumental(
        asset: MediaAsset,
        source: URL,
        mediaID: UUID,
        temporaryAudio: inout URL?
    ) async throws -> URL {
        if let stems = stemsByMediaID[mediaID],
           FileManager.default.fileExists(atPath: stems.instrumental.path) {
            return stems.instrumental
        }

        let prepared = try await TranscriptionAudioPreparer().prepare(
            source: source,
            kind: asset.kind,
            onProgress: { [weak self] fraction in
                self?.displayAIProgress(
                    title: "Подготовка минусовки",
                    detail: "Извлечение звука из видео",
                    fraction: fraction
                )
            }
        )
        if asset.kind == .video {
            temporaryAudio = prepared
        }

        let stems = try await separateAudio(audioURL: prepared, originalURL: source)
        stemsByMediaID[mediaID] = stems
        return stems.instrumental
    }
}
