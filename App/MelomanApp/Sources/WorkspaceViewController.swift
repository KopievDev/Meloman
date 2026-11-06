import AppKit

@MainActor
final class WorkspaceViewController: NSViewController {
    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let toolbar = makeToolbar()
        let workspace = makeWorkspace()
        let timeline = makeTimeline()

        for child in [toolbar, workspace, timeline] {
            child.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(child)
        }

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 70),

            workspace.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            workspace.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            workspace.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            timeline.topAnchor.constraint(equalTo: workspace.bottomAnchor),
            timeline.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            timeline.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            timeline.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            timeline.heightAnchor.constraint(equalToConstant: 220),
        ])

        view = root
    }

    private func makeToolbar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let title = label("Meloman", size: 23, weight: .bold)
        let subtitle = label("Караоке-видео редактор", size: 12, color: .secondaryLabelColor)
        let titleGroup = NSStackView(views: [title, subtitle])
        titleGroup.orientation = .vertical
        titleGroup.alignment = .leading
        titleGroup.spacing = 3

        let importButton = unavailableButton("Импорт", reason: "Импорт медиа появится в PR #2")
        let karaokeButton = unavailableButton("Караоке", reason: "Генерация караоке появится позднее")
        let exportButton = unavailableButton("Экспорт", reason: "Экспорт MP4 появится позднее")

        let actions = NSStackView(views: [importButton, karaokeButton, exportButton])
        actions.spacing = 10

        for child in [titleGroup, actions] {
            child.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(child)
        }

        NSLayoutConstraint.activate([
            titleGroup.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 24),
            titleGroup.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            actions.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -24),
            actions.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            titleGroup.trailingAnchor.constraint(lessThanOrEqualTo: actions.leadingAnchor, constant: -20),
        ])

        return bar
    }

    private func makeWorkspace() -> NSView {
        let library = makePanel(
            title: "МЕДИАТЕКА",
            description: "Здесь появятся ваши аудио, видео, изображения и GIF."
        )
        let inspector = makePanel(
            title: "ИНСПЕКТОР",
            description: "Здесь можно будет редактировать слова, тайминги, стили и аудио."
        )

        let preview = NSView()
        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor.black.cgColor

        let headline = label("Предпросмотр караоке", size: 22, weight: .semibold, color: .white)
        let hint = label("Импортируйте аудио или видеоклип, чтобы начать", size: 13, color: .lightGray)
        let previewText = NSStackView(views: [headline, hint])
        previewText.orientation = .vertical
        previewText.alignment = .centerX
        previewText.spacing = 12
        previewText.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(previewText)

        NSLayoutConstraint.activate([
            previewText.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
            previewText.centerYAnchor.constraint(equalTo: preview.centerYAnchor),
        ])

        let columns = NSStackView(views: [library, preview, inspector])
        columns.orientation = .horizontal
        columns.distribution = .fill
        columns.spacing = 1

        library.widthAnchor.constraint(equalToConstant: 220).isActive = true
        inspector.widthAnchor.constraint(equalToConstant: 260).isActive = true
        preview.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true

        return columns
    }

    private func makeTimeline() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let heading = label("ТАЙМЛАЙН", size: 11, weight: .semibold, color: .secondaryLabelColor)
        let placeholder = NSStackView(views: [
            timelineTrack("V1   Видео"),
            timelineTrack("K1   Караоке"),
            timelineTrack("A1   Аудио"),
        ])
        placeholder.orientation = .vertical
        placeholder.spacing = 1

        for child in [heading, placeholder] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: panel.topAnchor, constant: 17),
            heading.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 22),
            placeholder.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 16),
            placeholder.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            placeholder.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
        ])

        return panel
    }

    private func timelineTrack(_ text: String) -> NSView {
        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let title = label(text, size: 12, color: .secondaryLabelColor)
        title.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(title)

        NSLayoutConstraint.activate([
            track.heightAnchor.constraint(equalToConstant: 42),
            title.leadingAnchor.constraint(equalTo: track.leadingAnchor, constant: 12),
            title.centerYAnchor.constraint(equalTo: track.centerYAnchor),
        ])

        return track
    }

    private func makePanel(title: String, description: String) -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let heading = label(title, size: 11, weight: .semibold, color: .secondaryLabelColor)
        let hint = label(description, size: 12, color: .secondaryLabelColor)
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 0
        hint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for child in [heading, hint] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: panel.topAnchor, constant: 20),
            heading.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            hint.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 20),
            hint.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            hint.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
        ])

        return panel
    }

    private func unavailableButton(_ title: String, reason: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.isEnabled = false
        button.toolTip = reason
        return button
    }

    private func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }
}
