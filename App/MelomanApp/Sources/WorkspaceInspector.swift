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
        let languageTitle = label("ЯЗЫК РАСПОЗНАВАНИЯ", size: 11, color: .secondaryLabelColor)
        recognitionLanguage.addItems(withTitles: ["Авто", "Русский", "English"])
        recognitionLanguage.selectItem(at: 1)

        for child in [title, inspectorInfo, lyricsControls, languageTitle, recognitionLanguage] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            inspectorInfo.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            inspectorInfo.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            inspectorInfo.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -17),
            lyricsControls.topAnchor.constraint(equalTo: inspectorInfo.bottomAnchor, constant: 16),
            lyricsControls.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            lyricsControls.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -17),
            languageTitle.topAnchor.constraint(equalTo: lyricsControls.bottomAnchor, constant: 16),
            languageTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            recognitionLanguage.topAnchor.constraint(equalTo: languageTitle.bottomAnchor, constant: 5),
            recognitionLanguage.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            recognitionLanguage.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -17),
        ])

        return panel
    }

    func makeTimeline() -> NSView {
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

        let wordScroll = NSScrollView()
        wordScroll.hasHorizontalScroller = true
        wordScroll.drawsBackground = false
        lyricStrip.frame = NSRect(x: 0, y: 0, width: 660, height: 36)
        lyricStrip.onSelect = { [weak self] id, time in
            self?.selectLyricWord(id, seekTo: time)
        }
        wordScroll.documentView = lyricStrip

        let progressPanel = makeAIProgressPanel()
        for child in [heading, timelineInfo, tracks, wordScroll, statusLabel, progressPanel] {
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
            wordScroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 137),
            wordScroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            wordScroll.centerYAnchor.constraint(equalTo: tracks.arrangedSubviews[1].centerYAnchor),
            wordScroll.heightAnchor.constraint(equalToConstant: 40),
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
