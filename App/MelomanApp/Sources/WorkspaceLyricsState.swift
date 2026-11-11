import AppKit
import KaraokeEngine
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    func refreshKaraoke() {
        let mediaID = selectedMediaID
        let lyrics = mediaID.map { project.karaokeLines(for: $0) } ?? []
        preview.karaokeOverlay.lyrics = lyrics
        preview.karaokeOverlay.style = mediaID.map { project.karaokeStyle(for: $0) } ?? .init()
        preview.karaokeOverlay.pronunciation = mediaID.map { project.karaokePronunciation(for: $0) } ?? .init()
        refreshStyleControls()
        lyricStrip.lines = lyrics
        lyricStrip.duration = project.media.first(where: { $0.id == mediaID })?.duration ?? .zero
        let seconds = Double(lyricStrip.duration.microseconds) / 1_000_000
        lyricStrip.setFrameSize(NSSize(width: max(660, seconds * 45), height: 36))

        let words = lyrics.flatMap(\.words)
        if !words.contains(where: { $0.id == selectedWordID }) {
            selectedWordID = words.first?.id
        }
        lyricStrip.selectedWordID = selectedWordID
        lyricStrip.isTimingEditEnabled = mediaID != nil && !isBusy
        pronunciationStrip.lines = lyrics
        pronunciationStrip.duration = lyricStrip.duration
        pronunciationStrip.pronunciation = mediaID.map { project.karaokePronunciation(for: $0) }
        pronunciationStrip.setFrameSize(NSSize(width: max(660, seconds * 45), height: 32))
        pronunciationStrip.selectedWordID = selectedWordID
        pronunciationStrip.isTimingEditEnabled = mediaID != nil && !isBusy
        displaySelectedLyricWord()
        refreshPronunciationControls()

        karaokeButton.isEnabled = mediaID != nil && !isBusy
        recognizeButton.isEnabled = mediaID != nil && !isBusy
        exportButton.isEnabled = !isBusy && !lyrics.isEmpty
        undoLyricButton.isEnabled = !undoHistory.isEmpty
        redoLyricButton.isEnabled = !redoHistory.isEmpty
        updateStemButtons()
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
            pronunciationWordField.stringValue = ""
            return
        }

        lyricTextField.stringValue = word.text
        lyricStartField.stringValue = String(format: "%.3f", Double(word.start.microseconds) / 1_000_000)
        lyricEndField.stringValue = String(format: "%.3f", Double(word.end.microseconds) / 1_000_000)
        lyricHiddenCheck.state = word.isHidden ? .on : .off
        applyLyricButton.isEnabled = true
        let selectedIndex = (words.firstIndex(where: { $0.id == word.id }) ?? 0) + 1
        lyricSelectionInfo.stringValue = "Слово \(selectedIndex) из \(words.count)"
        pronunciationWordField.stringValue = selectedMediaID.flatMap { mediaID in
            project.karaokePronunciation(for: mediaID).text(for: word.id)
        } ?? ""
    }

    func refreshKaraokePlayhead(_ seconds: Double) {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int64.max) / 1_000_000,
              let timecode = Timecode(microseconds: Int64((seconds * 1_000_000).rounded()))
        else { return }
        preview.karaokeOverlay.playhead = timecode
        lyricStrip.playhead = timecode
        pronunciationStrip.playhead = timecode
    }
}
