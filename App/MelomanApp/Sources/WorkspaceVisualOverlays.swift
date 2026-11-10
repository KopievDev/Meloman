import AppKit
import AVFoundation
import MelomanDomain
import UniformTypeIdentifiers

@MainActor
extension WorkspaceViewController {
    func makeVisualOverlayControls() -> NSView {
        let title = label("V3 · ГРАФИКА ПОВЕРХ ВИДЕО", size: 11, weight: .semibold, color: .secondaryLabelColor)
        overlayMenu.target = self
        overlayMenu.action = #selector(overlaySelectionChanged(_:))
        addOverlayButton.target = self
        addOverlayButton.action = #selector(addVisualOverlay(_:))
        removeOverlayButton.target = self
        removeOverlayButton.action = #selector(removeVisualOverlay(_:))
        applyOverlayButton.target = self
        applyOverlayButton.action = #selector(applyVisualOverlay(_:))

        let buttons = NSStackView(views: [addOverlayButton, removeOverlayButton])
        buttons.orientation = .vertical
        buttons.alignment = .leading
        buttons.spacing = 5

        let column = NSStackView(views: [
            title, overlayMenu, buttons,
            overlayRow("Начало (с)", overlayStartField),
            overlayRow("Конец (с)", overlayEndField),
            overlayRow("X (%)", overlayXField),
            overlayRow("Y (%)", overlayYField),
            overlayRow("Ширина (%)", overlayWidthField),
            overlayHiddenCheck, applyOverlayButton,
        ])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 7
        refreshVisualOverlayControls()
        return column
    }

    private func overlayRow(_ title: String, _ field: NSTextField) -> NSView {
        let caption = label(title, size: 11, color: .secondaryLabelColor)
        field.widthAnchor.constraint(equalToConstant: 92).isActive = true
        let row = NSStackView(views: [caption, field])
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 6
        return row
    }

    func refreshVisualOverlays() {
        let overlays = selectedMediaID.map { project.overlays(for: $0) } ?? []
        if !overlays.contains(where: { $0.id == selectedOverlayID }) {
            selectedOverlayID = overlays.first?.id
        }
        visualOverlayStrip.overlays = overlays
        visualOverlayStrip.selectedOverlayID = selectedOverlayID
        visualOverlayStrip.duration = project.media.first(where: { $0.id == selectedMediaID })?.duration ?? .zero
        let seconds = Double(visualOverlayStrip.duration.microseconds) / 1_000_000
        visualOverlayStrip.setFrameSize(NSSize(width: max(660, seconds * 45), height: 32))
        preview.setVisualOverlays(overlays, urls: overlayURLs)
        let current = player.currentTime().seconds
        preview.updateVisualOverlays(at: current.isFinite ? max(0, current) : 0)
        refreshVisualOverlayControls()
    }

    func refreshVisualOverlayControls() {
        let overlays = selectedMediaID.map { project.overlays(for: $0) } ?? []
        overlayMenu.removeAllItems()
        for (index, overlay) in overlays.enumerated() {
            overlayMenu.addItem(withTitle: "Слой \(index + 1) · \(overlay.fileExtension.uppercased())")
            overlayMenu.lastItem?.representedObject = overlay.id.uuidString
        }
        if let index = overlays.firstIndex(where: { $0.id == selectedOverlayID }) {
            overlayMenu.selectItem(at: index)
        }
        let selected = overlays.first(where: { $0.id == selectedOverlayID })
        let enabled = selected != nil && !isBusy
        addOverlayButton.isEnabled = selectedMediaID != nil && !isBusy
        overlayMenu.isEnabled = !overlays.isEmpty && !isBusy
        removeOverlayButton.isEnabled = enabled
        applyOverlayButton.isEnabled = enabled
        overlayHiddenCheck.isEnabled = enabled
        for field in [overlayStartField, overlayEndField, overlayXField, overlayYField, overlayWidthField] {
            field.isEnabled = enabled
        }
        overlayStartField.stringValue = selected.map { formatOverlayTime($0.start) } ?? ""
        overlayEndField.stringValue = selected.map { formatOverlayTime($0.end) } ?? ""
        overlayXField.stringValue = selected.map { String(format: "%.1f", $0.centerX * 100) } ?? ""
        overlayYField.stringValue = selected.map { String(format: "%.1f", $0.centerY * 100) } ?? ""
        overlayWidthField.stringValue = selected.map { String(format: "%.1f", $0.width * 100) } ?? ""
        overlayHiddenCheck.state = selected?.isHidden == true ? .on : .off
    }

    private func formatOverlayTime(_ time: Timecode) -> String {
        String(format: "%.3f", Double(time.microseconds) / 1_000_000)
    }

    @objc func overlaySelectionChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let id = UUID(uuidString: raw)
        else { return }
        selectedOverlayID = id
        visualOverlayStrip.selectedOverlayID = id
        refreshVisualOverlayControls()
    }

    func selectVisualOverlay(_ id: UUID, seekTo time: Timecode) {
        selectedOverlayID = id
        visualOverlayStrip.selectedOverlayID = id
        player.seek(to: CMTime(value: time.microseconds, timescale: 1_000_000))
        refreshVisualOverlayControls()
        preview.updateVisualOverlays(at: Double(time.microseconds) / 1_000_000)
    }

    @objc func addVisualOverlay(_: Any?) {
        guard !isBusy,
              let id = selectedMediaID,
              let media = project.media.first(where: { $0.id == id })
        else { return }

        let panel = NSOpenPanel()
        panel.message = "Выберите PNG, JPEG, HEIC или GIF для слоя поверх видео"
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let ext = url.pathExtension.lowercased()
        guard VisualOverlay.supportedExtensions.contains(ext) else { return }
        let isValid = if ext == "gif" {
            KaraokeGIFFrames(url: url)?.frame(index: 0) != nil
        } else {
            NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil
        }
        guard isValid else {
            showError("Не удалось прочитать графический файл.")
            return
        }

        let total = Double(media.duration.microseconds) / 1_000_000
        guard total > 0.1 else { return }
        let now = player.currentTime().seconds
        let startSeconds = min(max(0, now.isFinite ? now : 0), max(0, total - 0.1))
        let endSeconds = min(total, startSeconds + 8)
        guard let start = Timecode(microseconds: Int64((startSeconds * 1_000_000).rounded())),
              let end = Timecode(microseconds: Int64((endSeconds * 1_000_000).rounded())),
              let overlay = VisualOverlay(mediaID: id, fileExtension: ext, start: start, end: end)
        else { return }

        project.upsertOverlay(overlay)
        overlayURLs[overlay.id] = url
        selectedOverlayID = overlay.id
        refreshVisualOverlays()
        statusLabel.stringValue = "Слой добавлен. Сохраните проект."
    }

    @objc func removeVisualOverlay(_: Any?) {
        guard !isBusy, let id = selectedOverlayID else { return }
        project.removeOverlay(id)
        overlayURLs.removeValue(forKey: id)
        selectedOverlayID = nil
        refreshVisualOverlays()
        statusLabel.stringValue = "Слой удалён. Сохраните проект."
    }

    @objc func applyVisualOverlay(_: Any?) {
        guard !isBusy,
              let id = selectedOverlayID,
              let old = (project.visualOverlays ?? []).first(where: { $0.id == id }),
              let media = project.media.first(where: { $0.id == old.mediaID }),
              let start = parseOverlayNumber(overlayStartField),
              let end = parseOverlayNumber(overlayEndField),
              let centerX = parseOverlayNumber(overlayXField),
              let centerY = parseOverlayNumber(overlayYField),
              let width = parseOverlayNumber(overlayWidthField),
              start >= 0, start < end,
              end <= Double(media.duration.microseconds) / 1_000_000,
              start < Double(Int64.max) / 1_000_000,
              end < Double(Int64.max) / 1_000_000,
              let startTime = Timecode(microseconds: Int64((start * 1_000_000).rounded())),
              let endTime = Timecode(microseconds: Int64((end * 1_000_000).rounded())),
              let updated = VisualOverlay(
                  id: old.id,
                  mediaID: old.mediaID,
                  fileExtension: old.fileExtension,
                  start: startTime,
                  end: endTime,
                  centerX: centerX / 100,
                  centerY: centerY / 100,
                  width: width / 100,
                  isHidden: overlayHiddenCheck.state == .on
              )
        else {
            showError("Проверьте секунды начала/конца и проценты X, Y, ширины (5–100%).")
            return
        }

        project.upsertOverlay(updated)
        refreshVisualOverlays()
        statusLabel.stringValue = "Слой обновлён. Сохраните проект."
    }

    private func parseOverlayNumber(_ field: NSTextField) -> Double? {
        Double(field.stringValue.replacingOccurrences(of: ",", with: "."))
    }
}
