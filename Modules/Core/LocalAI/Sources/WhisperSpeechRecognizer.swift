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

/// Loads a multilingual model once, then runs local word-level transcription.
/// Model download and decoding progress must not be mistaken for overall completion.
@MainActor
public final class WhisperSpeechRecognizer {
    public var onProgress: ((AIProcessingUpdate) -> Void)?

    private var isDownloadingModel = false
    private var isRecognizing = false
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
            try await loadModel()
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

    private func loadModel() async throws {
        let directory = try modelDirectory()
        let modelFolder = try await resolveModelFolder(in: directory)

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

    private func resolveModelFolder(in directory: URL) async throws -> URL {
        let marker = directory.appendingPathComponent(folderMarker)
        let savedPath = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""

        if !savedPath.isEmpty, FileManager.default.fileExists(atPath: savedPath) {
            onProgress?(AIProcessingUpdate(title: "Подготовка модели", detail: "Загрузка из локального кеша"))
            return URL(fileURLWithPath: savedPath)
        }

        isDownloadingModel = true
        onProgress?(AIProcessingUpdate(
            title: "Загрузка модели Whisper small",
            detail: "Скачивание на Mac, потребуется интернет"
        ))
        let folder = try await WhisperKit.download(
            variant: variant,
            downloadBase: directory,
            progressCallback: { [weak self] progress in
                let fraction = progress.totalUnitCount > 0 ? progress.fractionCompleted : nil
                Task { @MainActor [weak self] in
                    guard let self, isDownloadingModel else { return }
                    onProgress?(AIProcessingUpdate(
                        title: "Загрузка модели Whisper small",
                        detail: fraction.map {
                            "Скачано \(Int(max(0, min(1, $0)) * 100))% модели"
                        } ?? "Получение файлов модели",
                        fraction: fraction
                    ))
                }
            }
        )
        isDownloadingModel = false
        try folder.path.write(to: marker, atomically: true, encoding: .utf8)
        return folder
    }

    public func recognize(audioAt url: URL, language: String? = nil) async throws -> [RecognizedWord] {
        try await prepare()
        guard let engine else { throw SpeechRecognitionError.modelUnavailable }

        isRecognizing = true
        defer { isRecognizing = false }
        onProgress?(AIProcessingUpdate(
            title: "Шаг 2/3 · Распознавание песни",
            detail: "Обработка аудио — на плотной музыке точность может быть низкой"
        ))
        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            usePrefillPrompt: true,
            detectLanguage: language == nil,
            wordTimestamps: true
        )
        let results = try await engine.transcribe(
            audioPath: url.path,
            decodeOptions: options,
            callback: transcriptionCallback()
        )
        let words = recognizedWords(from: results)
        guard !words.isEmpty else { throw SpeechRecognitionError.noWords }
        onProgress?(AIProcessingUpdate(
            title: "Расшифровка готова",
            detail: "Проверьте слова и временные метки",
            isActive: false
        ))
        return words
    }

    private func transcriptionCallback() -> TranscriptionCallback {
        { [weak self] progress in
            let count = progress.tokens.count
            guard count > 0, count.isMultiple(of: 8) else { return nil }
            let window = progress.windowId + 1
            Task { @MainActor [weak self] in
                guard let self, isRecognizing else { return }
                onProgress?(AIProcessingUpdate(
                    title: "Шаг 2/3 · Распознавание песни",
                    detail: "Фрагмент \(window): обработано \(count) токенов (не слов)"
                ))
            }
            return nil
        }
    }

    private func recognizedWords(from results: [TranscriptionResult]) -> [RecognizedWord] {
        var words: [RecognizedWord] = []
        var segmentIndex = 0
        for result in results {
            for segment in result.segments {
                for word in segment.words ?? [] {
                    words.append(RecognizedWord(
                        text: word.word,
                        startSeconds: Double(word.start),
                        endSeconds: Double(word.end),
                        segment: segmentIndex
                    ))
                }
                segmentIndex += 1
            }
        }
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
