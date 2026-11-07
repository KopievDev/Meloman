import Foundation

/// Uses macOS's own Audio File Converter so no ffmpeg/Python installation is needed.
enum SpleeterAudioConverter {
    static func convert(input: URL, output: URL) async throws {
        let source = input
        let destination = output
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
            process.arguments = [
                "-f", "WAVE",
                "-d", "LEI16@44100",
                "-c", "2",
                source.path, destination.path,
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            try Task.checkCancellation()

            guard process.terminationStatus == 0, VocalStemCache.isValid(destination) else {
                throw VocalSeparationError.conversionFailed
            }
        }.value
    }
}
