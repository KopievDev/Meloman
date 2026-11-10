import AppKit
import AVFoundation
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
        videoBackgroundButton.target = self
        videoBackgroundButton.action = #selector(selectBackgroundVideo(_:))
        clearBackgroundButton.target = self
        clearBackgroundButton.action = #selector(removeBackground(_:))

        let controls = NSStackView(views: [
            backgroundButton, videoBackgroundButton, clearBackgroundButton,
        ])
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
        let videoURL = selectedMediaID.flatMap { backgroundVideoURLs[$0] }
        backgroundInfo.stringValue = if isAudio {
            videoURL?.lastPathComponent ?? imageURL?.lastPathComponent ?? "Чёрный фон"
        } else if selected != nil {
            "Используется исходное видео"
        } else {
            "Выберите аудиофайл"
        }
        backgroundButton.isEnabled = isAudio && !isBusy
        videoBackgroundButton.isEnabled = isAudio && !isBusy
        clearBackgroundButton.isEnabled = isAudio && !isBusy && (imageURL != nil || videoURL != nil)
    }

    func refreshBackgroundPreview() {
        let selected = project.media.first(where: { $0.id == selectedMediaID })
        let isAudio = selected?.kind == .audio
        preview.playerLayer.isHidden = isAudio
        let videoURL = isAudio ? selectedMediaID.flatMap { backgroundVideoURLs[$0] } : nil
        let imageURL = isAudio && videoURL == nil ? selectedMediaID.flatMap { backgroundURLs[$0] } : nil
        preview.backgroundGIF = nil
        preview.backgroundImage = nil
        if let imageURL {
            if imageURL.pathExtension.lowercased() == "gif" {
                preview.backgroundGIF = KaraokeGIFFrames(url: imageURL)
            } else {
                preview.backgroundImage = NSImage(contentsOf: imageURL)
            }
        }
        configureBackgroundVideo(videoURL)
        previewHint.stringValue = if isAudio, imageURL == nil, videoURL == nil {
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
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let valid = if url.pathExtension.lowercased() == "gif" {
            KaraokeGIFFrames(url: url) != nil
        } else if let image = NSImage(contentsOf: url) {
            image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil
        } else {
            false
        }
        guard valid
        else {
            showError("Не удалось открыть изображение или GIF фона.")
            return
        }

        project.setBackgroundImage(
            MediaBackgroundImage(mediaID: id, fileExtension: url.pathExtension),
            for: id
        )
        backgroundURLs[id] = url
        project.setBackgroundVideo(nil, for: id)
        backgroundVideoURLs.removeValue(forKey: id)
        refreshBackgroundPreview()
        refreshBackgroundControls()
        statusLabel.stringValue = "Фон обновлён. Сохраните проект."
    }

    @objc func removeBackground(_: Any?) {
        guard !isBusy, let id = selectedMediaID else { return }
        project.setBackgroundImage(nil, for: id)
        project.setBackgroundVideo(nil, for: id)
        backgroundURLs.removeValue(forKey: id)
        backgroundVideoURLs.removeValue(forKey: id)
        refreshBackgroundPreview()
        refreshBackgroundControls()
        statusLabel.stringValue = "Чёрный фон восстановлен. Сохраните проект."
    }
}
