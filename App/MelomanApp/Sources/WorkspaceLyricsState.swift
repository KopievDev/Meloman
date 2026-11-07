import AppKit
import KaraokeEngine
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    func refreshKaraoke() {
        let mediaID = selectedMediaID
        let lyrics = mediaID.map { project.karaokeLines(for: $0) } ?? []
        preview.karaokeOverlay.lyrics = lyrics
        lyricStrip.lines = lyrics
        lyricStrip.duration = project.media.first(where: { $0.id == mediaID })?.duration ?? .zero
        let seconds = Double(lyricStrip.duration.microseconds) / 1_000_000
        lyricStrip.setFrameSize(NSSize(width: max(660, seconds * 45), height: 36))

        let words = lyrics.flatMap(\.words)
        if !words.contains(where: { $0.id == selectedWordID }) {
            selectedWordID = words.first?.id
        }
        lyricStrip.selectedWordID = selectedWordID
        displaySelectedLyricWord()

        karaokeButton.isEnabled = mediaID != nil && !isBusy
        recognizeButton.isEnabled = mediaID != nil && !isBusy
        undoLyricButton.isEnabled = !undoHistory.isEmpty
        redoLyricButton.isEnabled = !redoHistory.isEmpty
    }

    func displaySelectedLyricWord() {
        let words = (selectedMediaID.map { project.karaokeLines(for: $0) } ?? []).flatMap(\.words)
        guard let word = words.first(where: { $0.id == selectedWordID }) else {
            lyricTextField.stringValue = ""
            lyricStartField.stringValue = ""
            lyricEndField.stringValue = ""
            lyricHiddenCheck.state = .off
            applyLyricButton.isEnabled = false
            lyricSelectionInfo.stringValue = "Вставьте текст песни"
            return
        }

        lyricTextField.stringValue = word.text
        lyricStartField.stringValue = String(format: "%.3f", Double(word.start.microseconds) / 1_000_000)
        lyricEndField.stringValue = String(format: "%.3f", Double(word.end.microseconds) / 1_000_000)
        lyricHiddenCheck.state = word.isHidden ? .on : .off
        applyLyricButton.isEnabled = true
        let selectedIndex = (words.firstIndex(where: { $0.id == word.id }) ?? 0) + 1
        lyricSelectionInfo.stringValue = "Слово \(selectedIndex) из \(words.count)"
    }

    func refreshKaraokePlayhead(_ seconds: Double) {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int64.max) / 1_000_000,
              let timecode = Timecode(microseconds: Int64((seconds * 1_000_000).rounded()))
        else { return }
        preview.karaokeOverlay.playhead = timecode
        lyricStrip.playhead = timecode
    }
}
