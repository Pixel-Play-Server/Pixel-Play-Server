import Foundation

@MainActor
final class AIOrchestrator: ObservableObject {
    @Published var progress = GenerationProgress()

    private let nim = NIMClient()
    private let imageFetcher = ImageFetcher()
    private let elevenLabs = ElevenLabsClient()
    private let videoPipeline = VideoPipeline()

    func generate(config: GenerationConfig) async {
        let projectID = UUID().uuidString
        AppLogger.log("Generación iniciada | tema: \(config.topic) | \(config.duration.label) | \(config.format.label)")
        progress = GenerationProgress(step: .generatingScript, progress: 0.05, message: "La IA escribe el guion…")

        do {
            AppLogger.log("Paso 1/4: generando guion con NVIDIA NIM (modelo auto)")
            let script = try await nim.generateScript(config: config)
            AppLogger.log("Guion OK: \(script.scenes.count) escenas, título: \(script.title)")
            progress.script = script
            progress.step = .fetchingImages
            progress.progress = 0.15
            progress.message = "Buscando imágenes en internet…"

            var resolvedScenes: [ResolvedScene] = []
            AppLogger.log("Paso 2/4: descargando imágenes (\(script.scenes.count) escenas)")
            for (index, scene) in script.scenes.enumerated() {
                let resolved = try await imageFetcher.fetchImage(for: scene, projectID: projectID)
                resolvedScenes.append(resolved)
                AppLogger.log("Imagen escena \(index + 1): \(scene.imageQuery)")
                progress.progress = 0.15 + (Double(index + 1) / Double(script.scenes.count)) * 0.25
                progress.message = "Imagen \(index + 1)/\(script.scenes.count) descargada"
            }

            progress.step = .generatingVoice
            progress.progress = 0.42
            progress.message = "Generando voz con ElevenLabs…"

            AppLogger.log("Paso 3/4: síntesis de voz ElevenLabs")
            let voiceURL = try await elevenLabs.synthesize(
                text: script.fullNarration,
                voiceID: config.voiceID,
                projectID: projectID
            )
            AppLogger.log("Voz OK: \(voiceURL.lastPathComponent)")

            progress.step = .renderingClips
            progress.progress = 0.5
            progress.message = "FFmpeg monta el video en tu iPhone…"

            AppLogger.log("Paso 4/4: pipeline FFmpeg")
            let outputURL = try await videoPipeline.render(
                script: script,
                scenes: resolvedScenes,
                voiceURL: voiceURL,
                format: config.format,
                projectID: projectID
            ) { [weak self] value, message in
                Task { @MainActor in
                    self?.progress.progress = value
                    self?.progress.message = message
                }
                AppLogger.log("FFmpeg progreso \(Int(value * 100))%: \(message)")
            }

            progress.step = .completed
            progress.progress = 1.0
            progress.outputURL = outputURL
            progress.message = "¡Tu reel está listo!"
            AppLogger.log("Generación completada: \(outputURL.path)")
        } catch {
            progress.step = .failed
            progress.error = error.localizedDescription
            progress.message = "Error en la generación"
            AppLogger.error("Generación fallida", error: error)
        }
    }

    func reset() {
        progress = GenerationProgress()
    }
}
