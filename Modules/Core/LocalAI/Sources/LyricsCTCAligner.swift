import Foundation
import MelomanDomain

public enum LyricsCTCAlignmentError: LocalizedError {
    case engineUnavailable
    case resourceUnavailable
    case audioConversion
    case processingFailed(String)
    case invalidResult

    public var errorDescription: String? {
        switch self {
        case .engineUnavailable:
            "Установите движок синхронизации: ./scripts/setup-aligner.sh в папке Meloman."
        case .resourceUnavailable:
            "Скрипт CTC не найден внутри сборки Meloman."
        case .audioConversion:
            "Не удалось подготовить аудио 16 кГц для акустической модели."
        case let .processingFailed(message):
            "Синхронизация не удалась: \(message)"
        case .invalidResult:
            "Акустическая модель вернула некорректный результат."
        }
    }
}

private struct CTCReference: Encodable {
    let schemaVersion: Int
    let lines: [LyricLine]
}

private struct CTCProgress: Decodable {
    let title: String
    let detail: String
    let fraction: Double?
}

private struct CTCTemporaryPaths {
    let root: URL

    var waveform: URL {
        root.appendingPathComponent("audio.wav")
    }

    var reference: URL {
        root.appendingPathComponent("reference.json")
    }

    var output: URL {
        root.appendingPathComponent("output.json")
    }

    var progress: URL {
        root.appendingPathComponent("progress.json")
    }

    var log: URL {
        root.appendingPathComponent("logs.txt")
    }
}

/// Optional local aligner: accepts known lyrics and returns times, never invented text.
/// The CTC subprocess runs separately from the AppKit event loop.
@MainActor
public final class LyricsCTCAligner {
    public var onProgress: ((AIProcessingUpdate) -> Void)?

    public init() {}

    public func align(audioURL: URL, lines: [LyricLine]) async throws -> AcousticLyricsAlignment {
        let engine = try executableURL()
        guard let script = Bundle.main.url(
            forResource: "lyrics_ctc_align",
            withExtension: "py"
        ) else {
            throw LyricsCTCAlignmentError.resourceUnavailable
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "meloman-ctc-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        return try await prepareAndAlign(
            audioURL: audioURL,
            lines: lines,
            paths: CTCTemporaryPaths(root: root),
            engine: engine,
            script: script
        )
    }

    private func prepareAndAlign(
        audioURL: URL,
        lines: [LyricLine],
        paths: CTCTemporaryPaths,
        engine: URL,
        script: URL
    ) async throws -> AcousticLyricsAlignment {
        onProgress?(AIProcessingUpdate(
            title: "Подготовка аудио для CTC",
            detail: "Преобразование в WAV 16 кГц, моно"
        ))
        try await Self.convert(input: audioURL, output: paths.waveform)
        try JSONEncoder().encode(CTCReference(schemaVersion: 1, lines: lines)).write(to: paths.reference)
        return try await runAligner(
            paths: paths,
            engine: engine,
            script: script,
            cache: modelCache()
        )
    }

    private func runAligner(
        paths: CTCTemporaryPaths,
        engine: URL,
        script: URL,
        cache: URL
    ) async throws -> AcousticLyricsAlignment {
        let process = Process()
        process.executableURL = engine
        process.arguments = [
            script.path,
            "--audio", paths.waveform.path,
            "--reference", paths.reference.path,
            "--output", paths.output.path,
            "--progress", paths.progress.path,
            "--cache", cache.path,
        ]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PYTORCH_ENABLE_MPS_FALLBACK": "1",
            "HF_HOME": cache.path,
            "HF_HUB_DISABLE_TELEMETRY": "1",
        ]) { _, new in new }
        FileManager.default.createFile(atPath: paths.log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: paths.log)
        defer { try? handle.close() }
        process.standardOutput = handle
        process.standardError = handle

        onProgress?(AIProcessingUpdate(
            title: "Запуск CTC для песенного текста",
            detail: "Модель загрузится локально; при первом запуске нужно несколько ГБ"
        ))
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
        }

        while process.isRunning {
            try Task.checkCancellation()
            if let update = readProgress(at: paths.progress) {
                onProgress?(update)
            }
            try await Task.sleep(for: .milliseconds(700))
        }
        process.waitUntilExit()
        try Task.checkCancellation()

        return try decodeProcessResult(paths: paths, exitCode: process.terminationStatus)
    }

    private func decodeProcessResult(
        paths: CTCTemporaryPaths,
        exitCode: Int32
    ) throws -> AcousticLyricsAlignment {
        guard exitCode == 0 else {
            let details = (try? String(contentsOf: paths.log, encoding: .utf8)) ?? ""
            throw LyricsCTCAlignmentError.processingFailed(String(details.suffix(500)))
        }
        guard let data = try? Data(contentsOf: paths.output),
              let result = try? JSONDecoder().decode(AcousticLyricsAlignment.self, from: data),
              result.schemaVersion == 1
        else { throw LyricsCTCAlignmentError.invalidResult }
        onProgress?(AIProcessingUpdate(
            title: "CTC: синхронизация готова",
            detail: "Времена слов рассчитаны, проверьте неточные участки",
            isActive: false
        ))
        return result
    }

    private func readProgress(at url: URL) -> AIProcessingUpdate? {
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(CTCProgress.self, from: data)
        else { return nil }
        return AIProcessingUpdate(
            title: value.title,
            detail: value.detail,
            fraction: value.fraction
        )
    }

    private func executableURL() throws -> URL {
        let appSupport = try supportRoot()
        let binary = appSupport.appendingPathComponent(
            "Meloman/Engines/LyricsAligner/bin/python"
        )
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw LyricsCTCAlignmentError.engineUnavailable
        }
        return binary
    }

    private func modelCache() throws -> URL {
        let directory = try supportRoot().appendingPathComponent(
            "Meloman/Models/LyricsCTC",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func supportRoot() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private nonisolated static func convert(input: URL, output: URL) async throws {
        let exitCode = try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
            process.arguments = [
                "-f", "WAVE",
                "-d", "LEI16@16000",
                "-c", "1",
                input.path, output.path,
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }.value
        guard exitCode == 0 else {
            throw LyricsCTCAlignmentError.audioConversion
        }
    }
}
