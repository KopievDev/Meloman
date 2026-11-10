import AppKit
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    func makeKaraokeStyleControls() -> NSView {
        let heading = label("ОФОРМЛЕНИЕ КАРАОКЕ", size: 11, weight: .semibold, color: .secondaryLabelColor)
        styleFontMenu.addItems(withTitles: KaraokeFont.allCases.map(\.displayName))
        styleFontMenu.target = self
        styleFontMenu.action = #selector(karaokeStyleChanged(_:))

        styleSizeSlider.isContinuous = false
        styleSizeSlider.target = self
        styleSizeSlider.action = #selector(karaokeStyleChanged(_:))
        stylePositionSlider.isContinuous = false
        stylePositionSlider.target = self
        stylePositionSlider.action = #selector(karaokeStyleChanged(_:))

        for well in [styleTextColor, styleHighlightColor] {
            well.target = self
            well.action = #selector(karaokeStyleChanged(_:))
            well.translatesAutoresizingMaskIntoConstraints = false
            well.widthAnchor.constraint(equalToConstant: 62).isActive = true
            well.heightAnchor.constraint(equalToConstant: 25).isActive = true
        }
        resetStyleButton.target = self
        resetStyleButton.action = #selector(resetKaraokeStyle(_:))
        undoStyleButton.target = self
        undoStyleButton.action = #selector(undoKaraokeStyle(_:))

        let sizeLine = styleRow(title: "Размер", control: styleSizeSlider, value: styleSizeLabel)
        let positionLine = styleRow(title: "Высота", control: stylePositionSlider, value: stylePositionLabel)
        let normal = colorRow("Обычный", well: styleTextColor)
        let active = colorRow("Подсветка", well: styleHighlightColor)
        let history = NSStackView(views: [undoStyleButton, resetStyleButton])
        history.spacing = 5
        history.distribution = .fillEqually

        let form = NSStackView(views: [
            heading, styleFontMenu, sizeLine, positionLine, normal, active, history,
        ])
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 8
        for row in [styleFontMenu, sizeLine, positionLine, normal, active, history] {
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
        }
        refreshStyleControls()
        return form
    }

    private func styleRow(title: String, control: NSView, value: NSTextField) -> NSView {
        let text = label(title, size: 11, color: .secondaryLabelColor)
        text.widthAnchor.constraint(equalToConstant: 47).isActive = true
        value.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        value.alignment = .right
        value.widthAnchor.constraint(equalToConstant: 37).isActive = true

        let row = NSStackView(views: [text, control, value])
        row.spacing = 5
        row.distribution = .fill
        return row
    }

    private func colorRow(_ title: String, well: NSColorWell) -> NSView {
        let text = label(title, size: 11, color: .secondaryLabelColor)
        let row = NSStackView(views: [text, well])
        row.spacing = 8
        row.distribution = .fill
        return row
    }

    func refreshStyleControls() {
        let style = selectedMediaID.map { project.karaokeStyle(for: $0) } ?? .init()
        styleFontMenu.selectItem(at: KaraokeFont.allCases.firstIndex(of: style.font) ?? 0)
        styleSizeSlider.doubleValue = style.fontSize
        stylePositionSlider.doubleValue = style.verticalPosition
        styleSizeLabel.stringValue = String(format: "%.0f", style.fontSize)
        stylePositionLabel.stringValue = String(format: "%.0f%%", style.verticalPosition * 100)
        styleTextColor.color = KaraokeStyleRendering.color(style.textColor)
        styleHighlightColor.color = KaraokeStyleRendering.color(style.highlightColor)

        let enabled = selectedMediaID != nil && !isBusy
        let controls: [NSControl] = [
            styleFontMenu, styleSizeSlider, stylePositionSlider,
            styleTextColor, styleHighlightColor, resetStyleButton,
        ]
        for control in controls {
            control.isEnabled = enabled
        }
        let hasUndo = selectedMediaID.map { !(styleUndoHistory[$0] ?? []).isEmpty } ?? false
        undoStyleButton.isEnabled = enabled && hasUndo
    }

    @objc func karaokeStyleChanged(_: Any?) {
        guard !isBusy, let id = selectedMediaID else { return }
        let previous = project.karaokeStyle(for: id)
        let index = styleFontMenu.indexOfSelectedItem
        let fonts = KaraokeFont.allCases
        let edited = KaraokeStyle(
            font: fonts.indices.contains(index) ? fonts[index] : .helveticaBold,
            fontSize: styleSizeSlider.doubleValue,
            textColor: KaraokeStyleRendering.rgb(styleTextColor.color),
            highlightColor: KaraokeStyleRendering.rgb(styleHighlightColor.color),
            verticalPosition: stylePositionSlider.doubleValue
        ).sanitized()
        applyKaraokeStyle(edited, replacing: previous, mediaID: id)
    }

    @objc func resetKaraokeStyle(_: Any?) {
        guard !isBusy, let id = selectedMediaID else { return }
        applyKaraokeStyle(KaraokeStyle(), replacing: project.karaokeStyle(for: id), mediaID: id)
    }

    @objc func undoKaraokeStyle(_: Any?) {
        guard !isBusy, let id = selectedMediaID,
              var history = styleUndoHistory[id],
              let previous = history.popLast()
        else { return }
        styleUndoHistory[id] = history
        project.setKaraokeStyle(previous, for: id)
        refreshKaraoke()
        statusLabel.stringValue = "Стиль отменён. Сохраните проект."
    }

    private func applyKaraokeStyle(_ edited: KaraokeStyle, replacing previous: KaraokeStyle, mediaID: UUID) {
        guard edited != previous else { return }
        var history = styleUndoHistory[mediaID] ?? []
        history.append(previous)
        if history.count > 30 {
            history.removeFirst()
        }
        styleUndoHistory[mediaID] = history
        project.setKaraokeStyle(edited, for: mediaID)
        refreshKaraoke()
        statusLabel.stringValue = "Стиль обновлён. Сохраните проект."
    }
}
