import AppKit

@MainActor
extension WorkspaceViewController {
    func makeInspector() -> NSView {
        let panel = makePanel()
        let title = label("ИНСПЕКТОР", size: 11, weight: .semibold, color: .secondaryLabelColor)
        inspectorInfo.textColor = .secondaryLabelColor
        inspectorInfo.maximumNumberOfLines = 0
        inspectorInfo.lineBreakMode = .byWordWrapping

        for child in [title, inspectorInfo] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            inspectorInfo.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            inspectorInfo.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 17),
            inspectorInfo.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -17),
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

        for child in [heading, timelineInfo, tracks, statusLabel] {
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
            statusLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            statusLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
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
