import AppKit
import ProjectStore

@MainActor
extension WorkspaceViewController {
    @objc func saveProject(_: Any?) {
        guard !isBusy else { return }
        let destination: URL
        if let existing = projectURL {
            destination = existing
        } else {
            let panel = NSSavePanel()
            panel.message = "Сохранить проект Meloman со всеми исходными медиа"
            panel.nameFieldStringValue = "\(project.name).meloman"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            destination = url.pathExtension == "meloman" ? url : url.appendingPathExtension("meloman")
        }

        let snapshot = ProjectBundle(
            project: project,
            mediaURLs: mediaURLs,
            backgroundURLs: backgroundURLs,
            backgroundVideoURLs: backgroundVideoURLs,
            overlayURLs: overlayURLs
        )
        isBusy = true
        setBusyControls()
        statusLabel.stringValue = "Сохранение проекта…"

        Task { @MainActor [weak self] in
            do {
                let saved = try await Task.detached(priority: .userInitiated) {
                    try ProjectStore().save(snapshot, to: destination)
                }.value
                self?.projectURL = destination
                self?.mediaURLs = saved.mediaURLs
                self?.backgroundURLs = saved.backgroundURLs
                self?.backgroundVideoURLs = saved.backgroundVideoURLs
                self?.overlayURLs = saved.overlayURLs
                self?.loadSelectedMedia()
                self?.statusLabel.stringValue = "Сохранено: \(destination.lastPathComponent)"
            } catch {
                self?.showError("Ошибка сохранения: \(error.localizedDescription)")
                self?.statusLabel.stringValue = "Не удалось сохранить проект"
            }
            self?.isBusy = false
            self?.setBusyControls()
        }
    }

    @objc func openProject(_: Any?) {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.message = "Выберите папку проекта с расширением .meloman"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isBusy = true
        setBusyControls()
        statusLabel.stringValue = "Открытие проекта…"

        Task { @MainActor [weak self] in
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try ProjectStore().open(at: url)
                }.value
                guard let self else { return }
                project = loaded.project
                selectedWordID = nil
                undoHistory.removeAll()
                redoHistory.removeAll()
                styleUndoHistory.removeAll()
                mediaURLs = loaded.mediaURLs
                backgroundURLs = loaded.backgroundURLs
                backgroundVideoURLs = loaded.backgroundVideoURLs
                overlayURLs = loaded.overlayURLs
                selectedOverlayID = nil
                projectURL = url
                selectedMediaID = project.media.first?.id
                refreshMediaList()
                loadSelectedMedia()
                view.window?.title = "Meloman — \(project.name)"
                statusLabel.stringValue = "Открыт: \(url.lastPathComponent)"
            } catch {
                self?.showError("Ошибка открытия: \(error.localizedDescription)")
                self?.statusLabel.stringValue = "Не удалось открыть проект"
            }
            self?.isBusy = false
            self?.setBusyControls()
        }
    }
}
