import AppKit
import AVFoundation
import MediaPipeline
import LocalAI
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
    let speechRecognizer = WhisperSpeechRecognizer()
    let recognizeButton = NSButton(title: "AI текст", target: nil, action: nil)
    private var didStartModel = false
    let player = AVPlayer()
    let lyricStrip = KaraokeTimelineStrip()
    let karaokeButton = NSButton(title: "Текст песни", target: nil, action: nil)
    let lyricTextField = NSTextField(string: "")
    let lyricStartField = NSTextField(string: "")
    let lyricEndField = NSTextField(string: "")
    let lyricHiddenCheck = NSButton(checkboxWithTitle: "Скрыть слово", target: nil, action: nil)
    let lyricSelectionInfo = NSTextField(labelWithString: "Вставьте текст песни")
    let applyLyricButton = NSButton(title: "Применить", target: nil, action: nil)
    let prevLyricButton = NSButton(title: "◀", target: nil, action: nil)
    let nextLyricButton = NSButton(title: "▶", target: nil, action: nil)
    let undoLyricButton = NSButton(title: "Отменить", target: nil, action: nil)
    let redoLyricButton = NSButton(title: "Повторить", target: nil, action: nil)
    var selectedWordID: UUID?
    var undoHistory: [KaraokeUndoSnapshot] = []
    var redoHistory: [KaraokeUndoSnapshot] = []
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
        refreshKaraoke()
        updatePlaybackUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = "Meloman — \(project.name)"
        if !didStartModel {
            didStartModel = true
            speechRecognizer.onStatus = { [weak self] message in
                self?.statusLabel.stringValue = message
            }
            Task { [weak self] in
                do {
                    try await self?.speechRecognizer.prepare()
                } catch {
                    self?.statusLabel.stringValue = "AI: ошибка модели — \(error.localizedDescription)"
                }
            }
        }

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
}
