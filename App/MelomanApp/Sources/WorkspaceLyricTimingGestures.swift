import AppKit
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    func configureLyricTimingGestures(for strip: KaraokeTimelineStrip) {
        strip.onEditPreview = { [weak self] wordID, lines in
            self?.previewLyricTimingEdit(lines, selectedWordID: wordID)
        }
        strip.onEditCommit = { [weak self] wordID, lines in
            self?.commitLyricTimingEdit(lines, selectedWordID: wordID)
        }
        strip.onEditCancel = { [weak self] in
            self?.refreshKaraoke()
        }
    }

    private func previewLyricTimingEdit(_ lines: [LyricLine], selectedWordID wordID: UUID) {
        guard !isBusy,
              let mediaID = selectedMediaID,
              project.karaokeLines(for: mediaID).flatMap(\.words).contains(where: { $0.id == wordID }),
              let word = lines.flatMap(\.words).first(where: { $0.id == wordID })
        else { return }

        selectedWordID = wordID
        lyricStrip.lines = lines
        lyricStrip.selectedWordID = wordID
        pronunciationStrip.lines = lines
        pronunciationStrip.selectedWordID = wordID
        preview.karaokeOverlay.lyrics = lines
        lyricTextField.stringValue = word.text
        lyricStartField.stringValue = String(format: "%.3f", Double(word.start.microseconds) / 1_000_000)
        lyricEndField.stringValue = String(format: "%.3f", Double(word.end.microseconds) / 1_000_000)
    }

    private func commitLyricTimingEdit(_ lines: [LyricLine], selectedWordID wordID: UUID) {
        guard !isBusy,
              let mediaID = selectedMediaID,
              project.karaokeLines(for: mediaID) != lines
        else {
            refreshKaraoke()
            return
        }
        selectedWordID = wordID
        editLyrics(lines, for: mediaID)
        statusLabel.stringValue = "Тайминг изменён мышью. ⌘Z — отмена, сохраните проект."
    }
}
