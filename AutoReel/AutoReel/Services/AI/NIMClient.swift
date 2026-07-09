import Foundation

enum NIMError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Falta la API key de NVIDIA NIM"
        case .invalidResponse: return "Respuesta inválida de NVIDIA NIM"
        case .decodingFailed(let detail): return "No se pudo interpretar el guion: \(detail)"
        }
    }
}

struct NIMClient: Sendable {
    private let baseURL = URL(string: "https://integrate.api.nvidia.com/v1")!
    private let model = "meta/llama-3.3-70b-instruct"

    func generateScript(config: GenerationConfig) async throws -> VideoScript {
        guard let apiKey = KeychainService.load(.nvidia), !apiKey.isEmpty else {
            throw NIMError.missingAPIKey
        }

        let systemPrompt = """
        Eres un director creativo de reels virales. Devuelve SOLO JSON válido sin markdown.
        El JSON debe seguir este esquema exacto:
        {
          "title": "string",
          "duration": number,
          "scenes": [
            {
              "id": 1,
              "duration": 5,
              "narration": "texto narrado",
              "image_query": "english search keywords for stock photo",
              "subtitle_style": "hook|bullet|normal",
              "transition": "fade|slideleft|slideright|wipeleft|none"
            }
          ],
          "music_mood": "upbeat motivational",
          "hashtags": ["#tag1", "#tag2"],
          "caption": "copy para la publicación"
        }
        Reglas:
        - image_query siempre en inglés, 3-5 palabras, pensado para Pexels
        - narration en \(config.language == "es" ? "español" : config.language)
        - duración total aproximada: \(config.duration.rawValue) segundos
        - tono: \(config.tone.promptHint)
        - 4-8 escenas según duración
        - primera escena con subtitle_style hook
        """

        let userPrompt = "Crea un reel sobre: \(config.topic)"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NIMError.decodingFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(body)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw NIMError.invalidResponse
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let scriptData = cleaned.data(using: .utf8) else {
            throw NIMError.decodingFailed("contenido vacío")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(VideoScript.self, from: scriptData)
        } catch {
            throw NIMError.decodingFailed(error.localizedDescription)
        }
    }

    func rankImageQuery(scene: String, candidates: [String]) async throws -> Int {
        guard let apiKey = KeychainService.load(.nvidia), !apiKey.isEmpty else {
            return 0
        }

        let prompt = """
        Escena: \(scene)
        Opciones de imagen (índices 0-\(candidates.count - 1)):
        \(candidates.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n"))
        Responde SOLO con el número del índice de la mejor opción.
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1,
            "max_tokens": 8
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let content = (choices.first?["message"] as? [String: Any])?["content"] as? String,
            let index = Int(content.trimmingCharacters(in: .whitespacesAndNewlines)),
            candidates.indices.contains(index)
        else {
            return 0
        }

        return index
    }
}
