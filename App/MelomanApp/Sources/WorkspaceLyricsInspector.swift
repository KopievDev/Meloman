import AppKit

@MainActor
extension WorkspaceViewController {
    func makeLyricsInspectorControls() -> NSView {
        let title = label("РЕДАКТОР КАРАОКЕ", size: 11, weight: .semibold, color: .secondaryLabelColor)
        let dragHelp = label(
            "K1/K2: тяните блок или его край · ⌥ вся строка · ⇧ без привязки",
            size: 10, color: .secondaryLabelColor
        )
        dragHelp.maximumNumberOfLines = 2
        lyricSelectionInfo.textColor = .secondaryLabelColor
        lyricSelectionInfo.font = .systemFont(ofSize: 11)

        lyricTextField.placeholderString = "Слово"
        lyricStartField.placeholderString = "Начало (с)"
        lyricEndField.placeholderString = "Конец (с)"
        lyricStartField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lyricEndField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lyricHiddenCheck.title = "Скрыть слово"
        lyricHiddenCheck.state = .off

        configureLyricButtons()

        let timings = NSStackView(views: [lyricStartField, lyricEndField])
        timings.spacing = 5
        timings.distribution = .fillEqually
        let actions = NSStackView(views: [prevLyricButton, applyLyricButton, nextLyricButton])
        actions.spacing = 5
        let history = NSStackView(views: [undoLyricButton, redoLyricButton])
        history.spacing = 5
        history.distribution = .fillEqually

        let form = NSStackView(views: [
            title,
            lyricSelectionInfo,
            dragHelp,
            lyricTextField,
            timings,
            lyricHiddenCheck,
            actions,
            history,
        ])
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 8
        form.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for row in [lyricTextField, timings, actions, history] {
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
        }
        return form
    }

    func configureLyricButtons() {
        applyLyricButton.title = "Применить"
        applyLyricButton.target = self
        applyLyricButton.action = #selector(applyLyricWord(_:))
        applyLyricButton.isEnabled = false

        prevLyricButton.title = "◀"
        prevLyricButton.target = self
        prevLyricButton.action = #selector(previousLyricWord(_:))

        nextLyricButton.title = "▶"
        nextLyricButton.target = self
        nextLyricButton.action = #selector(nextLyricWord(_:))

        undoLyricButton.title = "Отменить"
        undoLyricButton.target = self
        undoLyricButton.action = #selector(undoLyricChange(_:))
        undoLyricButton.isEnabled = false

        redoLyricButton.title = "Повторить"
        redoLyricButton.target = self
        redoLyricButton.action = #selector(redoLyricChange(_:))
        redoLyricButton.isEnabled = false
    }
}
