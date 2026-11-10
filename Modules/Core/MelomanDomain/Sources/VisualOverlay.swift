import Foundation

/// A timeline graphic above source footage/background and below karaoke text.
/// Center coordinates and width are normalized to the output canvas.
public struct VisualOverlay: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let mediaID: UUID
    public let fileExtension: String
    public var start: Timecode
    public var end: Timecode
    public var centerX: Double
    public var centerY: Double
    public var width: Double
    public var isHidden: Bool

    public init?(
        id: UUID = UUID(),
        mediaID: UUID,
        fileExtension: String,
        start: Timecode,
        end: Timecode,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        width: Double = 0.3,
        isHidden: Bool = false
    ) {
        let ext = fileExtension.lowercased()
        guard Self.supportedExtensions.contains(ext),
              start < end,
              (0 ... 1).contains(centerX),
              (0 ... 1).contains(centerY),
              (0.05 ... 1).contains(width)
        else { return nil }

        self.id = id
        self.mediaID = mediaID
        self.fileExtension = ext
        self.start = start
        self.end = end
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.isHidden = isHidden
    }

    public static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "gif"]

    public var packagedFilename: String {
        "\(id.uuidString).\(fileExtension)"
    }

    public func isActive(at time: Timecode) -> Bool {
        !isHidden && start <= time && time < end
    }
}

public extension MelomanProject {
    func overlays(for mediaID: UUID) -> [VisualOverlay] {
        (visualOverlays ?? []).filter { $0.mediaID == mediaID }
    }

    mutating func upsertOverlay(_ overlay: VisualOverlay) {
        var overlays = visualOverlays ?? []
        if let index = overlays.firstIndex(where: { $0.id == overlay.id }) {
            overlays[index] = overlay
        } else {
            overlays.append(overlay)
        }
        visualOverlays = overlays
    }

    mutating func removeOverlay(_ id: UUID) {
        visualOverlays?.removeAll(where: { $0.id == id })
    }
}
