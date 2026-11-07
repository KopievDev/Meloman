import Foundation
import MelomanDomain
import WhisperKit

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
    public var onStatus: ((String) -> Void)?

    private var engine: WhisperKit?
    private var preparation: Task<Void, Error>?

    private let variant = "small"
    private let folderMarker = "whisper-small-path.txt"

    public init() {}

    public func prepare() async throws {
        if engine != nil { return }
        if let preparation {
            return try await preparation.value
        }

        let task = Task { @MainActor in
            let directory = try modelDirectory()
            let marker = directory.appendingPathComponent(folderMarker)
            let modelFolder: URL

            if let path = try? String(contentsOf: marker, encoding: .utf8),
               FileManager.default.fileExists(atPath: path) {
                onStatus?("AI: загрузка локальной модели…")
                modelFolder = URL(fileURLWithPath: path)
            } else {
                onStatus?("AI: загрузка модели Whisper small (требуется интернет)…")
                modelFolder = try await WhisperKit.download(
                    variant: variant,
                    downloadBase: directory
                )
                try modelFolder.path.write(to: marker, atomically: true, encoding: .utf8)
            }

            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                verbose: false,
                load: true,
                download: false
            )
            engine = try await WhisperKit(config)
            onStatus?("AI: модель готова, обработка локальная")
        }

        preparation = task
        defer { preparation = nil }

        do {
            try await task.value
        } catch {
            onStatus?("AI: ошибка загрузки — повторите через кнопку AI")
            throw error
        }
    }

    public func recognize(audioAt url: URL) async throws -> [RecognizedWord] {
        try await prepare()
        guard let engine else { throw SpeechRecognitionError.modelUnavailable }

        onStatus?("AI: распознавание песни…")
        let options = DecodingOptions(
            task: .transcribe,
            language: nil,
            usePrefillPrompt: false,
            detectLanguage: true,
            wordTimestamps: true
        )
        let results = try await engine.transcribe(audioPath: url.path, decodeOptions: options)
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
        onStatus?("AI: распознавание завершено, проверьте слова и таймкоды")
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
