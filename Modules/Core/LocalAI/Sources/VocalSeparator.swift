import Foundation
@preconcurrency import Spleeter

/// Local derived files; original songs are never replaced.
public struct VocalStems: Sendable {
    public let vocals: URL
    public let instrumental: URL
    public let wasCached: Bool

    public init(vocals: URL, instrumental: URL, wasCached: Bool) {
        self.vocals = vocals
        self.instrumental = instrumental
        self.wasCached = wasCached
    }
}

public enum VocalSeparationError: LocalizedError {
    case invalidOutputs
    case conversionFailed
    case modelDownloadFailed
    case modelArchiveInvalid

    public var errorDescription: String? {
        switch self {
        case .invalidOutputs:
            "Нейросеть не создала две звуковые дорожки."
        case .conversionFailed:
            "Не удалось преобразовать песню в WAV для Core ML."
        case .modelDownloadFailed:
            "Не удалось скачать модель разделения вокала. Проверьте интернет."
        case .modelArchiveInvalid:
            "Архив нейросети не содержит нужную модель Core ML."
        }
    }
}

/// Spleeter 2-stem baseline. No Python/runtime server is required.
/// This produces a *derived* vocal track for ASR, not new lyrics or alignment.
@MainActor
public final class VocalSeparator {
    public var onProgress: ((AIProcessingUpdate) -> Void)?

    public init() {}

    public func separate(audioURL: URL, originalURL: URL) async throws -> VocalStems {
        onProgress?(AIProcessingUpdate(
            title: "Подготовка разделения",
            detail: "Проверка кеша дорожек"
        ))
        let key = try await VocalStemCache.key(for: originalURL)
        let destination = try VocalStemCache.directory(for: key)

        let vocals = destination.appendingPathComponent("vocals.wav")
        let instrumental = destination.appendingPathComponent("instrumental.wav")
        if VocalStemCache.isValid(vocals), VocalStemCache.isValid(instrumental) {
            onProgress?(AIProcessingUpdate(
                title: "Разделение готово",
                detail: "Дорожки взяты из локального кеша",
                isActive: false
            ))
            return VocalStems(vocals: vocals, instrumental: instrumental, wasCached: true)
        }

        let model = try await SpleeterModelInstaller().prepare { [weak self] update in
            self?.onProgress?(update)
        }

        return try await generateStems(
            audioURL: audioURL,
            model: model,
            destination: destination,
            vocals: vocals,
            instrumental: instrumental
        )
    }

    private func generateStems(
        audioURL: URL,
        model: URL,
        destination: URL,
        vocals: URL,
        instrumental: URL
    ) async throws -> VocalStems {
        let stage = destination.appendingPathComponent(".working-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stage) }

        let input = stage.appendingPathComponent("input.wav")
        onProgress?(AIProcessingUpdate(
            title: "Подготовка WAV",
            detail: "Преобразование аудио в 44,1 кГц"
        ))
        try await SpleeterAudioConverter.convert(input: audioURL, output: input)
        try Task.checkCancellation()

        onProgress?(AIProcessingUpdate(
            title: "Разделение вокала · Core ML",
            detail: "Нейросеть выделяет вокал и музыкальное сопровождение",
            fraction: 0
        ))
        let stagedVocals = stage.appendingPathComponent("vocals.wav")
        let stagedInstrumental = stage.appendingPathComponent("instrumental.wav")
        let separator = try AudioSeparator2(modelURL: model)
        for try await progress in separator.separate(
            from: input,
            to: Stems2(vocals: stagedVocals, accompaniment: stagedInstrumental)
        ) {
            try Task.checkCancellation()
            let fraction = progress.total > 0 ? Double(progress.current) / Double(progress.total) : nil
            onProgress?(AIProcessingUpdate(
                title: "Разделение вокала · Core ML",
                detail: "Обработано \(progress.current) из \(progress.total) фрагментов",
                fraction: fraction
            ))
        }

        guard VocalStemCache.isValid(stagedVocals), VocalStemCache.isValid(stagedInstrumental) else {
            throw VocalSeparationError.invalidOutputs
        }

        for (source, target) in [(stagedVocals, vocals), (stagedInstrumental, instrumental)] {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: source, to: target)
        }
        onProgress?(AIProcessingUpdate(
            title: "Разделение готово",
            detail: "Вокал и минусовка сохранены локально",
            isActive: false
        ))
        return VocalStems(vocals: vocals, instrumental: instrumental, wasCached: false)
    }
}
