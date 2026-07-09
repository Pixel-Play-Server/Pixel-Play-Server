import Foundation

struct VideoPipeline: Sendable {
    private let ffmpeg = FFmpegService()

    func render(
        script: VideoScript,
        scenes: [ResolvedScene],
        voiceURL: URL,
        format: VideoFormat,
        projectID: String,
        onProgress: @Sendable (Double, String) -> Void
    ) async throws -> URL {
        let (width, height) = format.size
        let workDir = MediaCache.projectDirectory(id: projectID)
        var clipPaths: [String] = []

        onProgress(0.55, "Renderizando clips con FFmpeg…")

        for (index, scene) in scenes.enumerated() {
            let clipPath = workDir.appendingPathComponent("clip_\(scene.plan.id).mp4").path
            try await ffmpeg.imageToClip(
                imagePath: scene.localImagePath,
                outputPath: clipPath,
                duration: scene.plan.duration,
                width: width,
                height: height
            )
            clipPaths.append(clipPath)
            let clipProgress = 0.55 + (Double(index + 1) / Double(scenes.count)) * 0.2
            onProgress(clipProgress, "Clip \(index + 1)/\(scenes.count) listo")
        }

        onProgress(0.78, "Uniendo escenas…")
        let mergedPath = workDir.appendingPathComponent("merged.mp4").path
        let transitions = scenes.map { $0.plan.transition }
        try await ffmpeg.concatClips(clipPaths: clipPaths, transitions: transitions, outputPath: mergedPath)

        onProgress(0.86, "Generando subtítulos…")
        let assContent = SubtitleGenerator.assFile(for: script, width: width, height: height)
        let assURL = try MediaCache.write(text: assContent, projectID: projectID, filename: "subtitles.ass")

        onProgress(0.92, "Mezclando voz y exportando…")
        let finalURL = workDir.appendingPathComponent("final_\(format.rawValue).mp4")
        try await ffmpeg.mixAudioAndSubtitles(
            videoPath: mergedPath,
            voicePath: voiceURL.path,
            subtitlePath: assURL.path,
            outputPath: finalURL.path,
            width: width,
            height: height
        )

        guard FileManager.default.fileExists(atPath: finalURL.path) else {
            throw FFmpegError.outputMissing
        }

        onProgress(1.0, "Video exportado")
        return finalURL
    }
}
