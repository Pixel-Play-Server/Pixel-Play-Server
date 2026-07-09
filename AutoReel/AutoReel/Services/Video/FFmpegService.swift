import Foundation

#if canImport(ffmpegkit)
import ffmpegkit
#endif

enum FFmpegError: LocalizedError {
    case notAvailable
    case commandFailed(String)
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "FFmpegKit no está disponible. Añade el paquete ffmpeg-kit-spm en Xcode."
        case .commandFailed(let log):
            return "FFmpeg falló: \(log)"
        case .outputMissing:
            return "No se generó el archivo de salida"
        }
    }
}

struct FFmpegService: Sendable {
    func run(_ arguments: [String]) async throws {
        let command = arguments.joined(separator: " ")
        AppLogger.log("FFmpeg: \(command)")

        #if canImport(ffmpegkit)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            FFmpegKit.executeAsync(command) { session in
                guard let session else {
                    AppLogger.error("FFmpeg sesión nula")
                    continuation.resume(throwing: FFmpegError.commandFailed("sesión FFmpeg nula"))
                    return
                }

                let returnCode = session.getReturnCode()
                if ReturnCode.isSuccess(returnCode) {
                    AppLogger.log("FFmpeg OK (código 0)")
                    continuation.resume()
                } else {
                    let logs = session.getAllLogsAsString() ?? "sin logs"
                    AppLogger.error("FFmpeg falló | código: \(returnCode?.getValue() ?? -1) | \(logs.prefix(500))")
                    continuation.resume(throwing: FFmpegError.commandFailed(logs))
                }
            }
        }
        #else
        throw FFmpegError.notAvailable
        #endif
    }

    func imageToClip(
        imagePath: String,
        outputPath: String,
        duration: Double,
        width: Int,
        height: Int
    ) async throws {
        let frames = Int(duration * 25)
        let filter = """
        scale=\(width):\(height):force_original_aspect_ratio=increase,crop=\(width):\(height),\
        zoompan=z='min(zoom+0.0015,1.25)':d=\(frames):x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=\(width)x\(height):fps=25
        """

        try await run([
            "-y",
            "-loop", "1",
            "-i", quote(imagePath),
            "-t", String(format: "%.2f", duration),
            "-vf", quote(filter),
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-r", "25",
            quote(outputPath)
        ])
    }

    func concatClips(
        clipPaths: [String],
        transitions: [SceneTransition],
        outputPath: String
    ) async throws {
        guard !clipPaths.isEmpty else { throw FFmpegError.outputMissing }

        if clipPaths.count == 1 {
            try FileManager.default.copyItem(atPath: clipPaths[0], toPath: outputPath)
            return
        }

        let listFile = (outputPath as NSString).deletingLastPathComponent + "/concat_list.txt"
        let listContent = clipPaths.map { "file '\($0)'" }.joined(separator: "\n")
        try listContent.write(toFile: listFile, atomically: true, encoding: .utf8)

        try await run([
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", quote(listFile),
            "-c", "copy",
            quote(outputPath)
        ])
    }

    func mixAudioAndSubtitles(
        videoPath: String,
        voicePath: String,
        subtitlePath: String?,
        outputPath: String,
        width: Int,
        height: Int
    ) async throws {
        if let subtitlePath {
            let vf = "subtitles=\(subtitlePath):force_style='FontName=Arial'"
            try await run([
                "-y",
                "-i", quote(videoPath),
                "-i", quote(voicePath),
                "-filter_complex", quote("[0:v]\(vf)[v];[1:a]volume=1.0[a]"),
                "-map", "[v]",
                "-map", "[a]",
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "23",
                "-c:a", "aac",
                "-b:a", "192k",
                "-shortest",
                quote(outputPath)
            ])
        } else {
            try await run([
                "-y",
                "-i", quote(videoPath),
                "-i", quote(voicePath),
                "-map", "0:v",
                "-map", "1:a",
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "23",
                "-c:a", "aac",
                "-b:a", "192k",
                "-shortest",
                quote(outputPath)
            ])
        }
    }

    private func quote(_ value: String) -> String {
        if value.contains(" ") { return "\"\(value)\"" }
        return value
    }
}
