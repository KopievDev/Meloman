import AppKit

@MainActor
extension WorkspaceViewController {
    func makeToolbar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let title = label("Meloman", size: 22, weight: .bold)
        let subtitle = label("Караоке-видео редактор", size: 12, color: .secondaryLabelColor)
        let identity = NSStackView(views: [title, subtitle])
        identity.orientation = .vertical
        identity.alignment = .leading
        identity.spacing = 3

        importButton.target = self
        importButton.action = #selector(importMedia(_:))
        openButton.target = self
        openButton.action = #selector(openProject(_:))
        saveButton.target = self
        saveButton.action = #selector(saveProject(_:))

        let karaoke = NSButton(title: "Караоке", target: nil, action: nil)
        karaoke.isEnabled = false
        karaoke.toolTip = "Генерация караоке появится в PR #3"
        let export = NSButton(title: "Экспорт", target: nil, action: nil)
        export.isEnabled = false
        export.toolTip = "Экспорт MP4 появится позднее"

        let buttons = NSStackView(views: [importButton, openButton, saveButton, karaoke, export])
        buttons.spacing = 8

        for child in [identity, buttons] {
            child.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(child)
        }

        NSLayoutConstraint.activate([
            identity.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 22),
            identity.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            buttons.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
            buttons.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            identity.trailingAnchor.constraint(lessThanOrEqualTo: buttons.leadingAnchor, constant: -16),
        ])

        return bar
    }

    func makeWorkspace() -> NSView {
        let library = makeLibrary()
        let inspector = makeInspector()
        let center = makePreview()

        let columns = NSStackView(views: [library, center, inspector])
        columns.orientation = .horizontal
        columns.distribution = .fill
        columns.spacing = 1

        library.widthAnchor.constraint(equalToConstant: 220).isActive = true
        inspector.widthAnchor.constraint(equalToConstant: 240).isActive = true
        center.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true

        return columns
    }

    func makeLibrary() -> NSView {
        let panel = makePanel()
        let title = label("МЕДИАТЕКА", size: 11, weight: .semibold, color: .secondaryLabelColor)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        mediaStack.orientation = .vertical
        mediaStack.alignment = .leading
        mediaStack.spacing = 7
        mediaStack.edgeInsets = NSEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        scroll.documentView = mediaStack

        for child in [title, scroll] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 13),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
        ])

        return panel
    }

    func makePreview() -> NSView {
        let center = NSView()
        let controls = makePlaybackControls()

        previewHint.textColor = .lightGray
        previewHint.font = .systemFont(ofSize: 17, weight: .medium)
        previewHint.maximumNumberOfLines = 2
        previewHint.lineBreakMode = .byTruncatingMiddle
        preview.addSubview(previewHint)
        previewHint.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            previewHint.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
            previewHint.centerYAnchor.constraint(equalTo: preview.centerYAnchor),
            previewHint.widthAnchor.constraint(lessThanOrEqualTo: preview.widthAnchor, constant: -36),
        ])

        for child in [preview, controls] {
            child.translatesAutoresizingMaskIntoConstraints = false
            center.addSubview(child)
        }

        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: center.topAnchor),
            preview.leadingAnchor.constraint(equalTo: center.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: center.trailingAnchor),
            controls.topAnchor.constraint(equalTo: preview.bottomAnchor),
            controls.leadingAnchor.constraint(equalTo: center.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: center.trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: center.bottomAnchor),
            controls.heightAnchor.constraint(equalToConstant: 52),
        ])

        return center
    }

    func makePlaybackControls() -> NSView {
        let controls = NSView()
        controls.wantsLayer = true
        controls.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        playButton.target = self
        playButton.action = #selector(togglePlayback(_:))
        playButton.isEnabled = false
        seekSlider.target = self
        seekSlider.action = #selector(seek(_:))
        seekSlider.isEnabled = false
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        for child in [playButton, seekSlider, timeLabel] {
            child.translatesAutoresizingMaskIntoConstraints = false
            controls.addSubview(child)
        }

        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: controls.leadingAnchor, constant: 12),
            playButton.centerYAnchor.constraint(equalTo: controls.centerYAnchor),
            seekSlider.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 10),
            seekSlider.centerYAnchor.constraint(equalTo: controls.centerYAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: seekSlider.trailingAnchor, constant: 12),
            timeLabel.centerYAnchor.constraint(equalTo: controls.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: controls.trailingAnchor, constant: -12),
            timeLabel.widthAnchor.constraint(equalToConstant: 105),
        ])
        return controls
    }
}
