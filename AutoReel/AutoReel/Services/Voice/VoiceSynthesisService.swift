import Foundation

struct VoiceSynthesisService: Sendable {
    private let elevenLabs = ElevenLabsClient()
    private let systemTTS = SystemTTSClient()

    func synthesize(text: String, config: GenerationConfig, projectID: String) async throws -> URL {
        switch config.voiceProvider {
        case .system:
            return try await systemTTS.synthesize(
                text: text,
                voiceID: config.voiceID,
                language: config.language,
                projectID: projectID
            )
        case .elevenLabs:
            guard KeychainService.load(.elevenLabs) != nil else {
                AppLogger.log("Sin API key ElevenLabs, usando voz gratis del iPhone", level: "WARN")
                return try await systemTTS.synthesize(
                    text: text,
                    voiceID: SystemVoice.defaultID(for: config.language),
                    language: config.language,
                    projectID: projectID
                )
            }

            do {
                return try await elevenLabs.synthesize(
                    text: text,
                    voiceID: config.voiceID,
                    projectID: projectID
                )
            } catch {
                AppLogger.error("ElevenLabs falló, fallback a voz del iPhone", error: error)
                return try await systemTTS.synthesize(
                    text: text,
                    voiceID: SystemVoice.defaultID(for: config.language),
                    language: config.language,
                    projectID: projectID
                )
            }
        }
    }

    var activeProviderLabel: String {
        "Voz"
    }
}
