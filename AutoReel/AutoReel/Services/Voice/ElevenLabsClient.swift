import Foundation

enum ElevenLabsError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case synthesisFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Falta la API key de ElevenLabs"
        case .invalidResponse: return "Respuesta inválida de ElevenLabs"
        case .synthesisFailed(let detail): return "Error de síntesis de voz: \(detail)"
        }
    }
}

struct ElevenLabsVoice: Identifiable {
    let id: String
    let name: String
    let language: String

    static let presets: [ElevenLabsVoice] = [
        ElevenLabsVoice(id: "EXAVITQu4vr4xnSDxMaL", name: "Sarah (EN)", language: "en"),
        ElevenLabsVoice(id: "pNInz6obpgDQGcFmaJgB", name: "Adam (EN)", language: "en"),
        ElevenLabsVoice(id: "onwK4e9ZLuTAKqWW03F9", name: "Daniel (ES)", language: "es"),
        ElevenLabsVoice(id: "gD1IexrzCvsXPHUuT0s3", name: "Marta (ES)", language: "es")
    ]
}

struct ElevenLabsClient: Sendable {
    private let baseURL = URL(string: "https://api.elevenlabs.io/v1")!

    func synthesize(text: String, voiceID: String, projectID: String) async throws -> URL {
        guard let apiKey = KeychainService.load(.elevenLabs), !apiKey.isEmpty else {
            throw ElevenLabsError.missingAPIKey
        }

        let resolvedVoiceID = ElevenLabsVoice.presets.first(where: { $0.id == voiceID })?.id
            ?? ElevenLabsVoice.presets.first(where: { $0.language == "es" })?.id
            ?? voiceID

        var request = URLRequest(url: baseURL.appendingPathComponent("text-to-speech/\(resolvedVoiceID)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.45,
                "similarity_boost": 0.8,
                "style": 0.35,
                "use_speaker_boost": true
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ElevenLabsError.invalidResponse }

        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "desconocido"
            throw ElevenLabsError.synthesisFailed(detail)
        }

        return try MediaCache.write(data: data, projectID: projectID, filename: "narration.mp3")
    }
}
