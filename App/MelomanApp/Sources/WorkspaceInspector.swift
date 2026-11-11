import AppKit

@MainActor
extension WorkspaceViewController {
    func makeInspector() -> NSView {
        let panel = makePanel()
        let title = label("ИНСПЕКТОР", size: 11, weight: .semibold, color: .secondaryLabelColor)
        inspectorInfo.textColor = .secondaryLabelColor
        inspectorInfo.maximumNumberOfLines = 4
        inspectorInfo.lineBreakMode = .byWordWrapping

        let lyricsControls = makeLyricsInspectorControls()
        let pronunciationControls = makePronunciationControls()
        let styleControls = makeKaraokeStyleControls()
        let backgroundControls = makeBackgroundControls()
        let overlayControls = makeVisualOverlayControls()
        let languageTitle = label("ЯЗЫК РАСПОЗНАВАНИЯ", size: 11, color: .secondaryLabelColor)
        recognitionLanguage.addItems(withTitles: ["Авто", "Русский", "English"])
        recognitionLanguage.selectItem(at: 1)
        let separation = makeVocalControls()

        let column = NSStackView(views: [
            title, inspectorInfo, lyricsControls, pronunciationControls, styleControls, backgroundControls,
            overlayControls, languageTitle, recognitionLanguage, separation,
        ])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 15
        for view in [
            inspectorInfo, lyricsControls, pronunciationControls, styleControls,
            backgroundControls, overlayControls, recognitionLanguage, separation,
        ] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }

        let container = NSView()
        container.addSubview(column)
        column.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = container
        container.translatesAutoresizingMaskIntoConstraints = false

        panel.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: panel.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),

            container.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            column.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            column.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])
        return panel
    }

    func makeTimeline() -> NSView {
        let panel = makePanel()
        let heading = label("ТАЙМЛАЙН", size: 11, weight: .semibold, color: .secondaryLabelColor)
        timelineInfo.textColor = .secondaryLabelColor
        let tracks = makeTimelineTrackLabels()

        let wordScroll = makeLyricTimelineScroll()
        let overlayScroll = makeGraphicTimelineScroll()
        let pronunciationScroll = makePronunciationTimelineScroll()

        let progressPanel = makeAIProgressPanel()
        let timelineViews = [
            heading, timelineInfo, tracks, overlayScroll, wordScroll, pronunciationScroll,
            statusLabel, progressPanel,
        ]
        for child in timelineViews {
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
            overlayScroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 137),
            overlayScroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            overlayScroll.centerYAnchor.constraint(equalTo: tracks.arrangedSubviews[1].centerYAnchor),
            overlayScroll.heightAnchor.constraint(equalToConstant: 34),
            wordScroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 137),
            wordScroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            wordScroll.centerYAnchor.constraint(equalTo: tracks.arrangedSubviews[2].centerYAnchor),
            wordScroll.heightAnchor.constraint(equalToConstant: 34),
            pronunciationScroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 137),
            pronunciationScroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            pronunciationScroll.centerYAnchor.constraint(equalTo: tracks.arrangedSubviews[3].centerYAnchor),
            pronunciationScroll.heightAnchor.constraint(equalToConstant: 34),
            statusLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: progressPanel.leadingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
            progressPanel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            progressPanel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -5),
            progressPanel.widthAnchor.constraint(equalToConstant: 390),
            progressPanel.heightAnchor.constraint(equalToConstant: 65),
        ])

        return panel
    }

    private func makeTimelineTrackLabels() -> NSStackView {
        let tracks = NSStackView(views: [
            label("V1   Видео", size: 12, color: .secondaryLabelColor),
            label("V3   Графика", size: 12, color: .secondaryLabelColor),
            label("K1   Караоке", size: 12, color: .secondaryLabelColor),
            label("K2   Произношение RU", size: 12, color: .secondaryLabelColor),
            label("A1   Аудио", size: 12, color: .secondaryLabelColor),
        ])
        tracks.orientation = .vertical
        tracks.alignment = .leading
        tracks.spacing = 12
        return tracks
    }

    private func makeLyricTimelineScroll() -> NSScrollView {
        let wordScroll = NSScrollView()
        wordScroll.hasHorizontalScroller = true
        wordScroll.drawsBackground = false
        lyricStrip.frame = NSRect(x: 0, y: 0, width: 660, height: 36)
        lyricStrip.onSelect = { [weak self] id, time in
            self?.selectLyricWord(id, seekTo: time)
        }
        configureLyricTimingGestures(for: lyricStrip)
        lyricStrip.toolTip = "Тяните слово для сдвига, края — для длительности. ⌥ — вся строка, ⇧ — без сетки."
        wordScroll.documentView = lyricStrip
        return wordScroll
    }

    private func makePronunciationTimelineScroll() -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = false
        pronunciationStrip.frame = NSRect(x: 0, y: 0, width: 660, height: 32)
        pronunciationStrip.onSelect = { [weak self] id, time in
            self?.selectLyricWord(id, seekTo: time)
        }
        configureLyricTimingGestures(for: pronunciationStrip)
        pronunciationStrip.toolTip = "K2 использует времена K1. Перетаскивание корректирует оба трека."
        scroll.documentView = pronunciationStrip
        return scroll
    }

    private func makeGraphicTimelineScroll() -> NSScrollView {
        let overlayScroll = NSScrollView()
        overlayScroll.hasHorizontalScroller = true
        overlayScroll.drawsBackground = false
        visualOverlayStrip.frame = NSRect(x: 0, y: 0, width: 660, height: 32)
        visualOverlayStrip.onSelect = { [weak self] id, time in
            self?.selectVisualOverlay(id, seekTo: time)
        }
        overlayScroll.documentView = visualOverlayStrip
        return overlayScroll
    }

    func makePanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        return panel
    }

    func label(
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
