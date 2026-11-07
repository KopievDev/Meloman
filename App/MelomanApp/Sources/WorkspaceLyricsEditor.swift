import AppKit
import AVFoundation
import KaraokeEngine
import MelomanDomain

struct KaraokeUndoSnapshot {
    let mediaID: UUID
    let lines: [LyricLine]
}

@MainActor
extension WorkspaceViewController {
    @objc func showLyricsInput(_: Any?) {
        guard let selected = project.media.first(where: { $0.id == selectedMediaID }) else {
            showError("Сначала импортируйте песню и выберите её.")
            return
        }

        let old = project.karaokeLines(for: selected.id)
        let alert = NSAlert()
        alert.messageText = "Текст караоке"
        alert.informativeText = "Вставьте текст с переносами строк. " +
            "Времена будут приблизительными: поправьте слова вручную."
        alert.addButton(withTitle: "Создать разметку")
        alert.addButton(withTitle: "Отмена")

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 230))
        scroll.hasVerticalScroller = true
        let textView = NSTextView(frame: scroll.bounds)
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.string = old
            .map { $0.words.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
        scroll.documentView = textView
        alert.accessoryView = scroll

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if !old.isEmpty {
            let confirm = NSAlert()
            confirm.messageText = "Заменить существующую разметку?"
            confirm.informativeText = "Ручные таймкоды этого трека будут заменены. Можно отменить через Undo."
            confirm.addButton(withTitle: "Заменить")
            confirm.addButton(withTitle: "Отмена")
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
        }

        let generated = LyricsDraftBuilder.build(text: textView.string, duration: selected.duration)
        guard !generated.isEmpty else {
            showError("Укажите хотя бы одно слово в тексте.")
            return
        }
        editLyrics(generated, for: selected.id)
        selectedWordID = generated.first?.words.first?.id
        refreshKaraoke()
        statusLabel.stringValue = "Черновые таймкоды созданы. Синхронизируйте слова вручную."
    }

    func editLyrics(_ lines: [LyricLine], for mediaID: UUID) {
        undoHistory.append(KaraokeUndoSnapshot(mediaID: mediaID, lines: project.karaokeLines(for: mediaID)))
        redoHistory.removeAll()
        project.setKaraokeLines(lines, for: mediaID)
        refreshKaraoke()
    }

    @objc func applyLyricWord(_: Any?) {
        guard let mediaID = selectedMediaID,
              let selected = project.media.first(where: { $0.id == mediaID }),
              let wordID = selectedWordID
        else { return }

        let text = lyricTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let startSeconds = Double(lyricStartField.stringValue.replacingOccurrences(of: ",", with: "."))
        let endSeconds = Double(lyricEndField.stringValue.replacingOccurrences(of: ",", with: "."))

        guard !text.isEmpty,
              let startSeconds, let endSeconds,
              startSeconds.isFinite, endSeconds.isFinite,
              startSeconds >= 0, startSeconds < endSeconds,
              endSeconds * 1_000_000 <= Double(selected.duration.microseconds),
              let start = Timecode(microseconds: Int64((startSeconds * 1_000_000).rounded())),
              let end = Timecode(microseconds: Int64((endSeconds * 1_000_000).rounded())),
              start < end
        else {
            showError("Введите слово и корректные таймкоды в секундах внутри длительности трека.")
            return
        }

        var lines = project.karaokeLines(for: mediaID)
        for lineIndex in lines.indices {
            guard let wordIndex = lines[lineIndex].words.firstIndex(where: { $0.id == wordID }) else { continue }
            guard let edited = LyricWord(
                id: wordID,
                text: text,
                start: start,
                end: end,
                isHidden: lyricHiddenCheck.state == .on
            ) else { return }
            lines[lineIndex].words[wordIndex] = edited
            editLyrics(lines, for: mediaID)
            statusLabel.stringValue = "Слово обновлено (не забудьте сохранить проект)"
            return
        }
    }

    @objc func previousLyricWord(_: Any?) {
        moveLyricSelection(by: -1)
    }

    @objc func nextLyricWord(_: Any?) {
        moveLyricSelection(by: 1)
    }

    func moveLyricSelection(by shift: Int) {
        guard let mediaID = selectedMediaID else { return }
        let words = project.karaokeLines(for: mediaID).flatMap(\.words)
        guard let index = words.firstIndex(where: { $0.id == selectedWordID }) else { return }
        let next = index + shift
        guard words.indices.contains(next) else { return }
        selectLyricWord(words[next].id, seekTo: words[next].start)
    }

    func selectLyricWord(_ id: UUID, seekTo time: Timecode) {
        selectedWordID = id
        let seconds = Double(time.microseconds) / 1_000_000
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1_000_000))
        refreshKaraoke()
    }

    @objc func undoLyricChange(_: Any?) {
        guard let last = undoHistory.popLast() else { return }
        redoHistory.append(KaraokeUndoSnapshot(
            mediaID: last.mediaID,
            lines: project.karaokeLines(for: last.mediaID)
        ))
        project.setKaraokeLines(last.lines, for: last.mediaID)
        selectedMediaID = last.mediaID
        loadSelectedMedia()
    }

    @objc func redoLyricChange(_: Any?) {
        guard let last = redoHistory.popLast() else { return }
        undoHistory.append(KaraokeUndoSnapshot(
            mediaID: last.mediaID,
            lines: project.karaokeLines(for: last.mediaID)
        ))
        project.setKaraokeLines(last.lines, for: last.mediaID)
        selectedMediaID = last.mediaID
        loadSelectedMedia()
    }
}
