import AppKit
import AVFoundation
import MediaPipeline
import MelomanDomain
import ProjectStore

@MainActor
final class WorkspaceViewController: NSViewController {
    var project = MelomanProject(name: "Новый проект")
    var projectURL: URL?
    var mediaURLs: [UUID: URL] = [:]
    var selectedMediaID: UUID?
    var isBusy = false

    let mediaImporter = MediaImporter()
    let player = AVPlayer()
    let mediaStack = NSStackView()
    let preview = MediaPreviewView()
    let previewHint = NSTextField(labelWithString: "Импортируйте аудио или видео")
    let inspectorInfo = NSTextField(labelWithString: "Выберите файл в медиатеке")
    let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    let timelineInfo = NSTextField(labelWithString: "Добавьте аудио или видео для начала")
    let statusLabel = NSTextField(labelWithString: "Готово")
    let seekSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    let playButton = NSButton(title: "▶", target: nil, action: nil)
    let importButton = NSButton(title: "Импорт", target: nil, action: nil)
    let openButton = NSButton(title: "Открыть проект", target: nil, action: nil)
    let saveButton = NSButton(title: "Сохранить", target: nil, action: nil)
    var timeObserver: Any?

    override func loadView() {
        let root = MediaDropView()
        root.onFilesDropped = { [weak self] urls in
            self?.addMedia(urls)
        }
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
            toolbar.heightAnchor.constraint(equalToConstant: 76),

            workspace.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            workspace.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            workspace.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            timeline.topAnchor.constraint(equalTo: workspace.bottomAnchor),
            timeline.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            timeline.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            timeline.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            timeline.heightAnchor.constraint(equalToConstant: 215),
        ])

        preview.playerLayer.player = player
        view = root
        refreshMediaList()
        updatePlaybackUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = "Meloman — \(project.name)"

        if timeObserver == nil {
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.15, preferredTimescale: 600),
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updatePlaybackUI()
                }
            }
        }
    }

    private func makeToolbar() -> NSView {
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

    private func makeWorkspace() -> NSView {
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

    private func makeLibrary() -> NSView {
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

    private func makePreview() -> NSView {
        let center = NSView()
        let controls = NSView()
        controls.wantsLayer = true
        controls.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

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

    private func makeInspector() -> NSView {
        let panel = makePanel()
        let title = label("ИНСПЕКТОР", size: 11, weight: .semibold, color: .secondaryLabelColor)
        inspectorInfo.textColor = .secondaryLabelColor
        inspectorInfo.maximumNumberOfLines = 0
        inspectorInfo.lineBreakMode = .byWordWrapping

        for child in [title, inspectorInfo] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            inspectorInfo.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            inspectorInfo.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            inspectorInfo.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -17),
        ])

        return panel
    }

    private func makeTimeline() -> NSView {
        let panel = makePanel()
        let heading = label("ТАЙМЛАЙН", size: 11, weight: .semibold, color: .secondaryLabelColor)
        timelineInfo.textColor = .secondaryLabelColor
        let tracks = NSStackView(views: [
            label("V1   Видео", size: 12, color: .secondaryLabelColor),
            label("K1   Караоке", size: 12, color: .secondaryLabelColor),
            label("A1   Аудио", size: 12, color: .secondaryLabelColor),
        ])
        tracks.orientation = .vertical
        tracks.alignment = .leading
        tracks.spacing = 20

        for child in [heading, timelineInfo, tracks, statusLabel] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        statusLabel.textColor = .secondaryLabelColor
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            heading.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            timelineInfo.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            timelineInfo.leadingAnchor.constraint(equalTo: heading.trailingAnchor, constant: 18),
            tracks.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 25),
            tracks.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            statusLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            statusLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])

        return panel
    }

    private func makePanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        return panel
    }

    private func label(
        _ value: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }
}
