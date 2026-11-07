import Foundation

/// Fetches a pinned official Core ML model archive once (about 36 MB).
/// The model is optional: it is downloaded on first use, not every app launch.
@MainActor
struct SpleeterModelInstaller {
    private let url = URL(
        string: "https://github.com/jiyimeta/swift-spleeter/releases/download/0.2.0/" +
            "Spleeter2Model.mlmodelc.zip"
    )!

    func prepare(onProgress: @escaping @MainActor (AIProcessingUpdate) -> Void) async throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent(
            "Meloman/Models/Spleeter2-0.2.0",
            isDirectory: true
        )
        let model = directory.appendingPathComponent("Spleeter2Model.mlmodelc", isDirectory: true)
        if isModelValid(model) {
            return model
        }

        onProgress(AIProcessingUpdate(
            title: "Загрузка модели Spleeter",
            detail: "Скачивание Core ML модели (~36 МБ), требуется интернет"
        ))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let (temporary, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200
        else { throw VocalSeparationError.modelDownloadFailed }

        let scratch = directory.appendingPathComponent(".unpack-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: scratch)
            try? FileManager.default.removeItem(at: temporary)
        }

        onProgress(AIProcessingUpdate(title: "Подготовка модели Spleeter", detail: "Распаковка модели Core ML"))
        try await extract(zip: temporary, to: scratch)
        let candidate = scratch.appendingPathComponent("Spleeter2Model.mlmodelc", isDirectory: true)
        guard isModelValid(candidate) else {
            throw VocalSeparationError.modelArchiveInvalid
        }
        try? FileManager.default.removeItem(at: model)
        try FileManager.default.moveItem(at: candidate, to: model)
        return model
    }

    private func isModelValid(_ url: URL) -> Bool {
        let manager = FileManager.default
        return manager.fileExists(atPath: url.appendingPathComponent("model.mil").path)
            && manager.fileExists(atPath: url.appendingPathComponent("weights/weight.bin").path)
    }

    private func extract(zip: URL, to destination: URL) async throws {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", zip.path, destination.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw VocalSeparationError.modelArchiveInvalid
            }
        }.value
    }
}
