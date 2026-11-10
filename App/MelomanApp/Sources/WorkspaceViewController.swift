import AppKit
import AVFoundation
import LocalAI
import MediaPipeline
import MelomanDomain
import ProjectStore

@MainActor
final class WorkspaceViewController: NSViewController {
    var project = MelomanProject(name: "Новый проект")
    var projectURL: URL?
    var mediaURLs: [UUID: URL] = [:]
    var backgroundURLs: [UUID: URL] = [:]
    var backgroundVideoURLs: [UUID: URL] = [:]
    var selectedMediaID: UUID?
    var isBusy = false

    let mediaImporter = MediaImporter()
    let speechRecognizer = WhisperSpeechRecognizer()
    let lyricsCTCAligner = LyricsCTCAligner()
    let syncLyricsButton = NSButton(title: "Синхронизировать текст", target: nil, action: nil)
    let vocalSeparator = VocalSeparator()
    let roFormerSeparator = MLXRoFormerSeparator()
    let separationQuality = NSPopUpButton(frame: .zero, pullsDown: false)
    var stemsByMediaID: [UUID: VocalStems] = [:]
    let useCleanVocals = NSButton(checkboxWithTitle: "Чистый вокал для AI", target: nil, action: nil)
    let separateButton = NSButton(title: "Отделить вокал", target: nil, action: nil)
    let playVocalsButton = NSButton(title: "Вокал", target: nil, action: nil)
    let playInstrumentalButton = NSButton(title: "Минус", target: nil, action: nil)
    let playOriginalButton = NSButton(title: "Оригинал", target: nil, action: nil)
    let recognizeButton = NSButton(title: "AI текст", target: nil, action: nil)
    let exportButton = NSButton(title: "Экспорт MP4", target: nil, action: nil)
    let movieExporter = KaraokeMovieExporter()
    let styleFontMenu = NSPopUpButton(frame: .zero, pullsDown: false)
    let styleSizeSlider = NSSlider(value: 56, minValue: 24, maxValue: 112, target: nil, action: nil)
    let stylePositionSlider = NSSlider(value: 0.18, minValue: 0.12, maxValue: 0.85, target: nil, action: nil)
    let styleSizeLabel = NSTextField(labelWithString: "56")
    let stylePositionLabel = NSTextField(labelWithString: "18%")
    let styleTextColor = NSColorWell()
    let styleHighlightColor = NSColorWell()
    let backgroundButton = NSButton(title: "Выбрать изображение…", target: nil, action: nil)
    let videoBackgroundButton = NSButton(title: "Выбрать видео…", target: nil, action: nil)
    let clearBackgroundButton = NSButton(title: "Сбросить фон", target: nil, action: nil)
    let backgroundInfo = NSTextField(labelWithString: "Чёрный фон")
    let resetStyleButton = NSButton(title: "Сбросить", target: nil, action: nil)
    let undoStyleButton = NSButton(title: "Отменить стиль", target: nil, action: nil)
    var styleUndoHistory: [UUID: [KaraokeStyle]] = [:]
    let recognitionLanguage = NSPopUpButton(frame: .zero, pullsDown: false)
    private var didStartModel = false
    let aiProgressPanel = NSView()
    let aiProgressTitle = NSTextField(labelWithString: "")
    let aiProgressDetail = NSTextField(labelWithString: "")
    let aiElapsedLabel = NSTextField(labelWithString: "")
    let aiProgressBar = NSProgressIndicator()
    let aiSpinner = NSProgressIndicator()
    var aiProgressStartedAt: Date?
    var aiProgressTimer: Timer?
    let player = AVPlayer()
    let backgroundPlayer = AVPlayer()
    var backgroundVideoDuration = 0.0
    var activeBackgroundVideoURL: URL?
    var backgroundDurationTask: Task<Void, Never>?
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
        preview.backgroundVideoLayer.player = backgroundPlayer
        backgroundPlayer.isMuted = true
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
            speechRecognizer.onProgress = { [weak self] update in
                self?.displayModelProgress(update)
            }
            lyricsCTCAligner.onProgress = { [weak self] update in
                self?.displayModelProgress(update)
            }
            vocalSeparator.onProgress = { [weak self] update in
                self?.displayModelProgress(update)
            }
            roFormerSeparator.onProgress = { [weak self] update in
                self?.displayModelProgress(update)
            }
            Task { [weak self] in
                do {
                    try await self?.speechRecognizer.prepare()
                } catch {
                    self?.displayAIProgress(
                        title: "Ошибка подготовки AI",
                        detail: error.localizedDescription,
                        active: false
                    )
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
