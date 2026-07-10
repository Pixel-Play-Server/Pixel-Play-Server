import Foundation

@MainActor
final class AIOrchestrator: ObservableObject {
    @Published var progress = GenerationProgress()

    private let nim = NIMClient()
    private let imageFetcher = ImageFetcher()
    private let voiceSynthesis = VoiceSynthesisService()
    private let videoPipeline = VideoPipeline()

    func generate(config: GenerationConfig) async {
        let projectID = UUID().uuidString
        AppLogger.log("Generación iniciada | tema: \(config.topic) | \(config.duration.label) | \(config.format.label)")
        progress = GenerationProgress(step: .warmingUpAI, progress: 0.02, message: "Conectando con la IA…")

        do {
            try Task.checkCancellation()

            AppLogger.log("Paso 0/4: inicialización NVIDIA NIM (warmup)")
            let warmedModel = try await TaskTimeout.run(seconds: 45, step: "inicialización NVIDIA") {
                try await self.nim.warmup()
            }
            AppLogger.log("Warmup listo, usando modelo prioritario: \(warmedModel)")

            try Task.checkCancellation()
            progress.step = .generatingScript
            progress.progress = 0.08
            progress.message = "La IA escribe el guion… No cierres la app."

            AppLogger.log("Paso 1/4: generando guion con NVIDIA NIM (modelo auto)")
            let script = try await TaskTimeout.run(seconds: 300, step: "guion NVIDIA") {
                try await self.nim.generateScript(config: config, preferredModel: warmedModel)
            }
            try Task.checkCancellation()

            AppLogger.log("Guion OK: \(script.scenes.count) escenas, título: \(script.title)")
            progress.script = script
            progress.step = .fetchingImages
            progress.progress = 0.15
            progress.message = "Buscando imágenes en internet…"

            var resolvedScenes: [ResolvedScene] = []
            AppLogger.log("Paso 2/4: descargando imágenes (\(script.scenes.count) escenas)")
            for (index, scene) in script.scenes.enumerated() {
                try Task.checkCancellation()
                progress.message = "Imagen \(index + 1)/\(script.scenes.count): \(scene.imageQuery)"

                let resolved = try await imageFetcher.fetchImage(for: scene, projectID: projectID)
                resolvedScenes.append(resolved)
                progress.progress = 0.15 + (Double(index + 1) / Double(script.scenes.count)) * 0.25
                progress.message = "Imagen \(index + 1)/\(script.scenes.count) lista"
            }

            try Task.checkCancellation()
            progress.step = .generatingVoice
            progress.progress = 0.42
            let voiceLabel = config.voiceProvider == .elevenLabs ? "ElevenLabs" : "iPhone (gratis)"
            progress.message = "Generando voz (\(voiceLabel))… No cierres la app."

            AppLogger.log("Paso 3/4: síntesis de voz (\(voiceLabel))")
            let voiceURL = try await TaskTimeout.run(seconds: 180, step: "voz \(voiceLabel)") {
                try await self.voiceSynthesis.synthesize(
                    text: script.fullNarration,
                    config: config,
                    projectID: projectID
                )
            }
            AppLogger.log("Voz OK: \(voiceURL.lastPathComponent)")

            try Task.checkCancellation()
            progress.step = .renderingClips
            progress.progress = 0.5
            progress.message = "FFmpeg monta el video en tu iPhone…"

            AppLogger.log("Paso 4/4: pipeline FFmpeg")
            let outputURL = try await TaskTimeout.run(seconds: 600, step: "montaje FFmpeg") {
                try await self.videoPipeline.render(
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
            }

            progress.step = .completed
            progress.progress = 1.0
            progress.outputURL = outputURL
            progress.message = "¡Tu reel está listo!"
            AppLogger.log("Generación completada: \(outputURL.path)")
        } catch is CancellationError {
            progress.step = .failed
            progress.error = "Cancelado por el usuario"
            progress.message = "Generación cancelada"
            AppLogger.log("Generación cancelada", level: "WARN")
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
