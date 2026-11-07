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

/// MLX 0.1.20 supports both model names via its built-in model resolver.
/// A cache revision is part of the asset identity, preventing cross-model reuse.
public enum MLXRoFormerModel: String, Sendable {
    case zfTurbo
    case bsRoFormer

    public var modelFileName: String {
        switch self {
        case .zfTurbo:
            "mel-roformer-zfturbo-vocals-v1-mlx"
        case .bsRoFormer:
            "model_bs_roformer_ep_317_sdr_12.9755.ckpt"
        }
    }

    public var cacheRevision: String {
        switch self {
        case .zfTurbo:
            "mlx-roformer-zfturbo-v1-0.1.20"
        case .bsRoFormer:
            "mlx-bs-roformer-ep317-0.1.20"
        }
    }

    public var displayName: String {
        switch self {
        case .zfTurbo: "Mel-Band RoFormer"
        case .bsRoFormer: "BS-RoFormer"
        }
    }
}

/// Optional high-quality engine. Calls a private local MLX executable; no cloud ASR.
@MainActor
public final class MLXRoFormerSeparator {
    public var onProgress: ((AIProcessingUpdate) -> Void)?

    public nonisolated static let modelRevision = "mlx-roformer-zfturbo-v1-0.1.20"

    public init() {}

    public func separate(
        audioURL: URL,
        originalURL: URL,
        model: MLXRoFormerModel = .zfTurbo
    ) async throws -> VocalStems {
        let executable = try engineExecutable()
        let key = try await VocalStemCache.key(for: originalURL)
        let folder = try VocalStemCache.directory(for: key, revision: model.cacheRevision)
        let vocals = folder.appendingPathComponent("vocals.wav")
        let instrumental = folder.appendingPathComponent("instrumental.wav")

        if VocalStemCache.isValid(vocals), VocalStemCache.isValid(instrumental) {
            onProgress?(AIProcessingUpdate(
                title: "\(model.displayName): готово",
                detail: "Дорожки взяты из локального кеша",
                isActive: false
            ))
            return VocalStems(vocals: vocals, instrumental: instrumental, wasCached: true)
        }

        let temp = folder.appendingPathComponent(".running-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        onProgress?(AIProcessingUpdate(
            title: "\(model.displayName) · MLX",
            detail: "Загрузка весов или обработка песни на Mac (без процента)"
        ))

        let input = audioURL
        let output = temp
        let modelFolder = try cacheModelsDirectory()
        let modelName = model.modelFileName
        let result = try await Task.detached(priority: .userInitiated) {
            try Self.run(
                executable: executable,
                audio: input,
                output: output,
                models: modelFolder,
                modelName: modelName
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
            title: "\(model.displayName): готово",
            detail: "Вокал и минусовка сохранены в собственном кеше",
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
        models: URL,
        modelName: String
    ) throws -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = [
            audio.path,
            "--model_filename", modelName,
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
        let message = String(bytes: bytes.suffix(3000), encoding: .utf8) ?? "Не удалось прочитать лог MLX"
        return (process.terminationStatus, message)
    }
}
