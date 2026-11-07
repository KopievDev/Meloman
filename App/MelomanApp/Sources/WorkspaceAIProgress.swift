import AppKit
import LocalAI

/// One task panel for extraction, model download and transcription.
/// Percentages are displayed only when the underlying task reports actual progress.
@MainActor
extension WorkspaceViewController {
    func makeAIProgressPanel() -> NSView {
        let panel = aiProgressPanel
        aiProgressTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        aiProgressDetail.font = .systemFont(ofSize: 11)
        aiProgressDetail.textColor = .secondaryLabelColor
        aiElapsedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        aiElapsedLabel.textColor = .secondaryLabelColor
        aiProgressBar.style = .bar
        aiProgressBar.minValue = 0
        aiProgressBar.maxValue = 100
        aiProgressBar.isIndeterminate = false
        aiProgressBar.isHidden = true
        aiSpinner.style = .spinning
        aiSpinner.controlSize = .small
        aiSpinner.isHidden = true

        for child in [aiProgressTitle, aiProgressDetail, aiElapsedLabel, aiProgressBar, aiSpinner] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }

        NSLayoutConstraint.activate([
            aiSpinner.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 2),
            aiSpinner.centerYAnchor.constraint(equalTo: aiProgressTitle.centerYAnchor),
            aiSpinner.widthAnchor.constraint(equalToConstant: 16),
            aiSpinner.heightAnchor.constraint(equalToConstant: 16),

            aiProgressTitle.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            aiProgressTitle.topAnchor.constraint(equalTo: panel.topAnchor, constant: 3),
            aiProgressTitle.trailingAnchor.constraint(lessThanOrEqualTo: aiElapsedLabel.leadingAnchor, constant: -8),

            aiElapsedLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            aiElapsedLabel.centerYAnchor.constraint(equalTo: aiProgressTitle.centerYAnchor),

            aiProgressDetail.topAnchor.constraint(equalTo: aiProgressTitle.bottomAnchor, constant: 4),
            aiProgressDetail.leadingAnchor.constraint(equalTo: aiProgressTitle.leadingAnchor),
            aiProgressDetail.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor),

            aiProgressBar.topAnchor.constraint(equalTo: aiProgressDetail.bottomAnchor, constant: 5),
            aiProgressBar.leadingAnchor.constraint(equalTo: aiProgressTitle.leadingAnchor),
            aiProgressBar.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            aiProgressBar.heightAnchor.constraint(equalToConstant: 7),
        ])

        panel.isHidden = true
        return panel
    }

    func displayAIProgress(
        title: String,
        detail: String,
        fraction: Double? = nil,
        active: Bool = true
    ) {
        if aiProgressStartedAt == nil, active {
            aiProgressStartedAt = Date()
            aiProgressTimer = Timer.scheduledTimer(
                timeInterval: 1,
                target: self,
                selector: #selector(refreshAIElapsed(_:)),
                userInfo: nil,
                repeats: true
            )
        }

        aiProgressPanel.isHidden = false
        aiProgressTitle.stringValue = title
        aiProgressDetail.stringValue = detail

        if active {
            if let fraction, fraction.isFinite {
                aiProgressBar.doubleValue = max(0, min(1, fraction)) * 100
                aiProgressBar.isHidden = false
                aiSpinner.isHidden = true
                aiSpinner.stopAnimation(nil)
            } else {
                aiProgressBar.isHidden = true
                aiSpinner.isHidden = false
                aiSpinner.startAnimation(nil)
            }
        } else {
            aiSpinner.stopAnimation(nil)
            aiSpinner.isHidden = true
            aiProgressBar.isHidden = true
            aiProgressTimer?.invalidate()
            aiProgressTimer = nil
            aiProgressStartedAt = nil
            aiElapsedLabel.stringValue = ""
        }
    }

    func displayModelProgress(_ update: AIProcessingUpdate) {
        displayAIProgress(
            title: update.title,
            detail: update.detail,
            fraction: update.fraction,
            active: update.isActive
        )
        statusLabel.stringValue = update.title
    }

    @objc func refreshAIElapsed(_: Timer) {
        guard let started = aiProgressStartedAt else { return }
        let elapsed = max(0, Int(Date().timeIntervalSince(started)))
        aiElapsedLabel.stringValue = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }
}
