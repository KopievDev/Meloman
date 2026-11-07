import Foundation

public enum MLXRoFormerError: LocalizedError {
    case unavailable
    case processFailed(String)
    case invalidStems

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Для качественного разделения установите MLX: выполните ./scripts/setup-mlx.sh " +
                "в папке Meloman. Требуется Apple Silicon и Python 3.10–3.13."
        case let .processFailed(message):
            "MLX не смог разделить дорожки: \(message)"
        case .invalidStems:
            "MLX завершился, но не создал полноценные дорожки вокала и минусовки."
        }
    }
}

/// Optional high-quality engine. Calls a private local MLX executable; no cloud ASR.
@MainActor
public final class MLXRoFormerSeparator {
    public var onProgress: ((AIProcessingUpdate) -> Void)?

    public static let modelRevision = "mlx-roformer-zfturbo-v1-0.1.20"

    public init() {}

    public func separate(audioURL: URL, originalURL: URL) async throws -> VocalStems {
        let executable = try engineExecutable()
        let key = try await VocalStemCache.key(for: originalURL)
        let folder = try VocalStemCache.directory(for: key, revision: Self.modelRevision)
        let vocals = folder.appendingPathComponent("vocals.wav")
        let instrumental = folder.appendingPathComponent("instrumental.wav")

        if VocalStemCache.isValid(vocals), VocalStemCache.isValid(instrumental) {
            onProgress?(AIProcessingUpdate(
                title: "RoFormer: готово",
                detail: "Дорожки взяты из локального кеша",
                isActive: false
            ))
            return VocalStems(vocals: vocals, instrumental: instrumental, wasCached: true)
        }

        let temp = folder.appendingPathComponent(".running-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        onProgress?(AIProcessingUpdate(
            title: "RoFormer · MLX",
            detail: "Загрузка модели или обработка песни на Mac (без процента)"
        ))

        let input = audioURL
        let output = temp
        let modelFolder = try cacheModelsDirectory()
        let result = try await Task.detached(priority: .userInitiated) {
            try Self.run(
                executable: executable,
                audio: input,
                output: output,
                models: modelFolder
            )
        }.value

        guard result.exitCode == 0 else {
            throw MLXRoFormerError.processFailed(result.output)
        }

        let stageVocals = temp.appendingPathComponent("vocals.wav")
        let stageInstrumental = temp.appendingPathComponent("instrumental.wav")
        guard VocalStemCache.isValid(stageVocals), VocalStemCache.isValid(stageInstrumental) else {
            throw MLXRoFormerError.invalidStems
        }

        try? FileManager.default.removeItem(at: vocals)
        try? FileManager.default.removeItem(at: instrumental)
        try FileManager.default.moveItem(at: stageVocals, to: vocals)
        try FileManager.default.moveItem(at: stageInstrumental, to: instrumental)

        onProgress?(AIProcessingUpdate(
            title: "RoFormer: готово",
            detail: "Вокал и минусовка сохранены отдельно от Spleeter",
            isActive: false
        ))
        return VocalStems(vocals: vocals, instrumental: instrumental, wasCached: false)
    }

    private func engineExecutable() throws -> URL {
        let root = try supportRoot()
        let binary = root.appendingPathComponent(
            "Meloman/Engines/MLX/bin/mlx-audio-separator"
        )
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw MLXRoFormerError.unavailable
        }
        return binary
    }

    private func cacheModelsDirectory() throws -> URL {
        let url = try supportRoot()
            .appendingPathComponent("Meloman/Models/MLX", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func supportRoot() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private nonisolated static func run(
        executable: URL,
        audio: URL,
        output: URL,
        models: URL
    ) throws -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = [
            audio.path,
            "--model_filename", "mel-roformer-zfturbo-vocals-v1-mlx",
            "--output_format", "WAV",
            "--output_dir", output.path,
            "--model_file_dir", models.path,
            "--custom_output_names", "{\"Vocals\":\"vocals\",\"Instrumental\":\"instrumental\"}",
        ]

        // Read combined logs continuously to avoid a blocked subprocess on full pipes.
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let message = String(decoding: bytes.suffix(3000), as: UTF8.self)
        return (process.terminationStatus, message)
    }
}
