import AppKit
import MelomanDomain
import UniformTypeIdentifiers

@MainActor
extension WorkspaceViewController {
    func makeBackgroundControls() -> NSView {
        let heading = label("ФОН ДЛЯ АУДИО", size: 11, weight: .semibold, color: .secondaryLabelColor)
        backgroundInfo.textColor = .secondaryLabelColor
        backgroundInfo.maximumNumberOfLines = 2
        backgroundInfo.lineBreakMode = .byTruncatingMiddle

        backgroundButton.target = self
        backgroundButton.action = #selector(selectBackgroundImage(_:))
        clearBackgroundButton.target = self
        clearBackgroundButton.action = #selector(removeBackgroundImage(_:))

        let controls = NSStackView(views: [backgroundButton, clearBackgroundButton])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 7

        let column = NSStackView(views: [heading, backgroundInfo, controls])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        refreshBackgroundControls()
        return column
    }

    func refreshBackgroundControls() {
        let selected = project.media.first(where: { $0.id == selectedMediaID })
        let isAudio = selected?.kind == .audio
        let imageURL = selectedMediaID.flatMap { backgroundURLs[$0] }
        backgroundInfo.stringValue = if isAudio {
            imageURL?.lastPathComponent ?? "Чёрный фон"
        } else if selected != nil {
            "Используется исходное видео"
        } else {
            "Выберите аудиофайл"
        }
        backgroundButton.isEnabled = isAudio && !isBusy
        clearBackgroundButton.isEnabled = isAudio && !isBusy && imageURL != nil
    }

    func refreshBackgroundPreview() {
        let selected = project.media.first(where: { $0.id == selectedMediaID })
        let isAudio = selected?.kind == .audio
        preview.playerLayer.isHidden = isAudio
        let imageURL = isAudio ? selectedMediaID.flatMap { backgroundURLs[$0] } : nil
        preview.backgroundImage = imageURL.flatMap { NSImage(contentsOf: $0) }
        previewHint.stringValue = if isAudio, imageURL == nil {
            selected.map { "♫  \($0.name)" } ?? ""
        } else {
            ""
        }
    }

    @objc func selectBackgroundImage(_: Any?) {
        guard !isBusy,
              let id = selectedMediaID,
              project.media.first(where: { $0.id == id })?.kind == .audio
        else { return }

        let panel = NSOpenPanel()
        panel.message = "Выберите изображение для фона караоке"
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url),
              image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil
        else {
            showError("Не удалось открыть изображение фона.")
            return
        }

        project.setBackgroundImage(
            MediaBackgroundImage(mediaID: id, fileExtension: url.pathExtension),
            for: id
        )
        backgroundURLs[id] = url
        refreshBackgroundPreview()
        refreshBackgroundControls()
        statusLabel.stringValue = "Фон обновлён. Сохраните проект."
    }

    @objc func removeBackgroundImage(_: Any?) {
        guard !isBusy, let id = selectedMediaID else { return }
        project.setBackgroundImage(nil, for: id)
        backgroundURLs.removeValue(forKey: id)
        refreshBackgroundPreview()
        refreshBackgroundControls()
        statusLabel.stringValue = "Чёрный фон восстановлен. Сохраните проект."
    }
}
