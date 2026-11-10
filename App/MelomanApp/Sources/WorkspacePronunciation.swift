import AppKit
import KaraokeEngine
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    func makePronunciationControls() -> NSView {
        let title = label("K2 · РУССКОЕ ПРОИЗНОШЕНИЕ", size: 11, weight: .semibold, color: .secondaryLabelColor)
        let subtitle = label("Подсказка по звучанию, не перевод", size: 11, color: .secondaryLabelColor)
        subtitle.maximumNumberOfLines = 2
        pronunciationToggle.target = self
        pronunciationToggle.action = #selector(togglePronunciation(_:))
        pronunciationDraftButton.target = self
        pronunciationDraftButton.action = #selector(generatePronunciationDraft(_:))
        pronunciationWordField.placeholderString = "Например: лук, иф, ю, хад"
        pronunciationApplyButton.target = self
        pronunciationApplyButton.action = #selector(applyPronunciationWord(_:))

        let column = NSStackView(views: [
            title, subtitle, pronunciationToggle,
            pronunciationDraftButton, pronunciationWordField,
            pronunciationApplyButton,
        ])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 7
        pronunciationWordField.translatesAutoresizingMaskIntoConstraints = false
        pronunciationWordField.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        refreshPronunciationControls()
        return column
    }

    func refreshPronunciationControls() {
        let hasLyrics = selectedMediaID.map {
            !project.karaokeLines(for: $0).flatMap(\.words).isEmpty
        } == true
        let enabled = hasLyrics && !isBusy
        let track = selectedMediaID.map { project.karaokePronunciation(for: $0) } ?? .init()
        pronunciationToggle.isEnabled = enabled
        pronunciationToggle.state = track.isEnabled ? .on : .off
        pronunciationDraftButton.isEnabled = enabled
        pronunciationWordField.isEnabled = enabled && selectedWordID != nil
        pronunciationApplyButton.isEnabled = enabled && selectedWordID != nil
    }

    @objc func togglePronunciation(_: Any?) {
        guard !isBusy, let mediaID = selectedMediaID else { return }
        var track = project.karaokePronunciation(for: mediaID)
        track.isEnabled = pronunciationToggle.state == .on
        if track.isEnabled, track.words.isEmpty {
            track = EnglishToRussianPronunciation.fillMissing(
                track: track, lines: project.karaokeLines(for: mediaID)
            )
        }
        project.setKaraokePronunciation(track, for: mediaID)
        refreshKaraoke()
        statusLabel.stringValue = "Произношение RU обновлено. Сохраните проект."
    }

    @objc func generatePronunciationDraft(_: Any?) {
        guard !isBusy, let mediaID = selectedMediaID else { return }
        var track = project.karaokePronunciation(for: mediaID)
        track = EnglishToRussianPronunciation.fillMissing(
            track: track, lines: project.karaokeLines(for: mediaID)
        )
        track.isEnabled = true
        project.setKaraokePronunciation(track, for: mediaID)
        refreshKaraoke()
        statusLabel.stringValue = "Черновик произношения создан. Проверьте слова вручную."
    }

    @objc func applyPronunciationWord(_: Any?) {
        guard !isBusy,
              let mediaID = selectedMediaID,
              let wordID = selectedWordID,
              project.karaokeLines(for: mediaID).flatMap(\.words).contains(where: { $0.id == wordID })
        else { return }
        var track = project.karaokePronunciation(for: mediaID)
        track.setText(pronunciationWordField.stringValue, for: wordID)
        project.setKaraokePronunciation(track, for: mediaID)
        refreshKaraoke()
        statusLabel.stringValue = "Русское произношение слова обновлено. Сохраните проект."
    }
}
