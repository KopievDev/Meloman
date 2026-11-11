import AppKit
import MelomanDomain

@MainActor
extension WorkspaceViewController {
    func configureTimelineZoom(_ scrollViews: [NSScrollView]) {
        timelineZoomSlider.target = self
        timelineZoomSlider.action = #selector(changeTimelineZoom(_:))
        timelineZoomLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        timelineZoomLabel.textColor = .secondaryLabelColor
        timelineZoomSlider.toolTip = "Масштаб для точного редактирования K1/K2 и графики V3"
        timelineScrollViews = scrollViews

        for scroll in scrollViews {
            scroll.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(timelineClipBoundsChanged(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scroll.contentView
            )
        }
    }

    func timelineWidth(for duration: Timecode) -> CGFloat {
        let seconds = CGFloat(duration.microseconds) / 1_000_000
        return max(660, seconds * timelinePixelsPerSecond)
    }

    @objc private func changeTimelineZoom(_ sender: NSSlider) {
        timelinePixelsPerSecond = CGFloat(sender.doubleValue)
        timelineZoomLabel.stringValue = "\(Int(timelinePixelsPerSecond.rounded())) px/с"
        lyricStrip.setFrameSize(NSSize(width: timelineWidth(for: lyricStrip.duration), height: 36))
        pronunciationStrip.setFrameSize(NSSize(
            width: timelineWidth(for: pronunciationStrip.duration), height: 32
        ))
        visualOverlayStrip.setFrameSize(NSSize(
            width: timelineWidth(for: visualOverlayStrip.duration), height: 32
        ))
        let time = player.currentTime().seconds
        guard time.isFinite, time >= 0, let first = timelineScrollViews.first else { return }
        let x = max(0, CGFloat(time) * timelinePixelsPerSecond - first.contentView.bounds.width / 2)
        first.contentView.scroll(to: NSPoint(x: x, y: 0))
        first.reflectScrolledClipView(first.contentView)
    }

    @objc private func timelineClipBoundsChanged(_ notification: Notification) {
        guard !synchronizingTimelineScroll,
              let source = notification.object as? NSClipView,
              timelineScrollViews.contains(where: { $0.contentView === source })
        else { return }
        synchronizingTimelineScroll = true
        defer { synchronizingTimelineScroll = false }
        let x = source.bounds.origin.x
        for scroll in timelineScrollViews where scroll.contentView !== source {
            scroll.contentView.scroll(to: NSPoint(x: x, y: 0))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }
}
