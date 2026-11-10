import Foundation
import MelomanDomain

extension ProjectStore {
    func stageVisualOverlays(
        _ bundle: ProjectBundle,
        in directory: URL,
        destination: URL
    ) throws -> [UUID: URL] {
        let manager = FileManager.default
        var result: [UUID: URL] = [:]
        for overlay in bundle.project.visualOverlays ?? [] {
            try validateOverlay(overlay)
            guard let source = bundle.overlayURLs[overlay.id],
                  manager.fileExists(atPath: source.path)
            else { throw ProjectStoreError.missingOverlay(overlay.packagedFilename) }

            try manager.copyItem(at: source, to: directory.appendingPathComponent(overlay.packagedFilename))
            result[overlay.id] = destination
                .appendingPathComponent("Overlays", isDirectory: true)
                .appendingPathComponent(overlay.packagedFilename)
        }
        return result
    }

    func readVisualOverlays(_ project: MelomanProject, in url: URL) throws -> [UUID: URL] {
        var result: [UUID: URL] = [:]
        for overlay in project.visualOverlays ?? [] {
            try validateOverlay(overlay)
            let file = url
                .appendingPathComponent("Overlays", isDirectory: true)
                .appendingPathComponent(overlay.packagedFilename)
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw ProjectStoreError.missingOverlay(overlay.packagedFilename)
            }
            result[overlay.id] = file
        }
        return result
    }

    private func validateOverlay(_ overlay: VisualOverlay) throws {
        guard VisualOverlay.supportedExtensions.contains(overlay.fileExtension),
              overlay.start < overlay.end,
              (0 ... 1).contains(overlay.centerX),
              (0 ... 1).contains(overlay.centerY),
              (0.05 ... 1).contains(overlay.width)
        else { throw ProjectStoreError.invalidOverlay(overlay.packagedFilename) }
    }
}
