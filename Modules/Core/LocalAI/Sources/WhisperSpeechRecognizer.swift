import Foundation
import MelomanDomain
@preconcurrency import WhisperKit

public enum SpeechRecognitionError: LocalizedError {
    case noWords
    case modelUnavailable

    public var errorDescription: String? {
        switch self {
        case .noWords:
            "Модель не определила слова и временные метки. Попробуйте другой файл или ручной ввод."
        case .modelUnavailable:
            "Модель распознавания ещё не готова."
        }
    }
}

/// Owned by the UI's main actor. Downloads a multilingual model once to Application Support,
/// initializes it automatically at launch and reuses it offline on subsequent launches.
@MainActor
public final class WhisperSpeechRecognizer {
    public var onProgress: ((AIProcessingUpdate) -> Void)?\n    private var isDownloadingModel = false\n    private var isRecognizing = false

    private var engine: WhisperKit?
    private var preparation: Task<Void, Error>?

    private let variant = "small"
    private let folderMarker = "whisper-small-path.txt"

    public init() {}

    public func prepare() async throws {
        if engine != nil {
            return
        }
        if let preparation {
            return try await preparation.value
        }

        let task = Task { @MainActor in
            let directory = try modelDirectory()
            let marker = directory.appendingPathComponent(folderMarker)
            let modelFolder: URL

            let savedPath = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""
            if !savedPath.isEmpty, FileManager.default.fileExists(atPath: savedPath) {
                onProgress?(AIProcessingUpdate(title: "Подготовка модели", detail: "Загрузка из локального кеша"))
                modelFolder = URL(fileURLWithPath: savedPath)
            } else {
                isDownloadingModel = true
                onProgress?(AIProcessingUpdate(
                    title: "Загрузка модели Whisper small",
                    detail: "Скачивание на Mac, потребуется интернет"
                ))
                modelFolder = try await WhisperKit.download(
                    variant: variant,
                    downloadBase: directory,
                    progressCallback: { [weak self] progress in
                        let fraction = progress.totalUnitCount > 0 ? progress.fractionCompleted : nil
                        Task { @MainActor [weak self] in
                            guard let self, self.isDownloadingModel else { return }
                            let detail = fraction.map {
                                "Скачано \(Int(max(0, min(1, $0)) * 100))% данных модели"
                            } ?? "Получение файлов модели"
                            self.onProgress?(AIProcessingUpdate(
                                title: "Загрузка модели Whisper small",
                                detail: detail,
                                fraction: fraction
                            ))
                        }
                    }
                )
                isDownloadingModel = false
                try modelFolder.path.write(to: marker, atomically: true, encoding: .utf8)
            }

            onProgress?(AIProcessingUpdate(title: "Инициализация модели", detail: "Подготовка Core ML"))
            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                verbose: false,
                load: true,
                download: false
            )
            engine = try await WhisperKit(config)
            onProgress?(AIProcessingUpdate(
                title: "AI готов",
                detail: "Whisper small доступна офлайн",
                isActive: false
            ))
        }

        preparation = task
        defer { preparation = nil }

        do {
            try await task.value
        } catch {
            isDownloadingModel = false
            onProgress?(AIProcessingUpdate(
                title: "Ошибка модели",
                detail: error.localizedDescription,
                isActive: false
            ))
            throw error
        }
    }

    public func recognize(audioAt url: URL) async throws -> [RecognizedWord] {
        try await prepare()
        guard let engine else { throw SpeechRecognitionError.modelUnavailable }

        isRecognizing = true
        onProgress?(AIProcessingUpdate(
            title: "Распознавание песни",
            detail: "Whisper анализирует аудио, это может занять несколько минут"
        ))
        let options = DecodingOptions(
            task: .transcribe,
            language: nil,
            usePrefillPrompt: false,
            detectLanguage: true,
            wordTimestamps: true
        )
        defer { isRecognizing = false }
        let results = try await engine.transcribe(
            audioPath: url.path,
            decodeOptions: options,
            callback: { [weak self] progress in
                let count = progress.tokens.count
                guard count > 0, count.isMultiple(of: 8) else { return nil }
                let window = progress.windowId + 1
                Task { @MainActor [weak self] in
                    guard let self, self.isRecognizing else { return }
                    self.onProgress?(AIProcessingUpdate(
                        title: "Распознавание песни",
                        detail: "Фрагмент \(window): обработано \(count) токенов (не слов)"
                    ))
                }
                return nil
            }
        )
        var words: [RecognizedWord] = []
        var segmentIndex = 0

        for result in results {
            for segment in result.segments {
                for word in segment.words ?? [] {
                    words.append(
                        RecognizedWord(
                            text: word.word,
                            startSeconds: Double(word.start),
                            endSeconds: Double(word.end),
                            segment: segmentIndex
                        )
                    )
                }
                segmentIndex += 1
            }
        }
        guard !words.isEmpty else { throw SpeechRecognitionError.noWords }
        onProgress?(AIProcessingUpdate(
            title: "AI: расшифровка готова",
            detail: "Проверьте слова и временные метки",
            isActive: false
        ))
        return words
    }

    private func modelDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Meloman/Models", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
