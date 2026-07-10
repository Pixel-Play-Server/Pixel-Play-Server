import Foundation

enum NIMError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decodingFailed(String)
    case allModelsFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Falta la API key de NVIDIA NIM"
        case .invalidResponse: return "Respuesta inválida de NVIDIA NIM"
        case .decodingFailed(let detail): return "No se pudo interpretar la respuesta: \(detail)"
        case .allModelsFailed(let detail): return "Ningún modelo NVIDIA respondió: \(detail)"
        }
    }
}

/// Cliente OpenAI-compatible para integrate.api.nvidia.com con streaming SSE.
struct NIMChatClient: Sendable {
    private let baseURL = URL(string: "https://integrate.api.nvidia.com/v1")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func complete(
        task: NIMModels.Task,
        messages: [[String: String]],
        temperature: Double,
        maxTokens: Int,
        seed: Int? = 42
    ) async throws -> String {
        guard let apiKey = KeychainService.load(.nvidia), !apiKey.isEmpty else {
            throw NIMError.missingAPIKey
        }

        var lastError: Error?
        for model in NIMModels.candidates(for: task) {
            let modelMaxTokens = NIMModels.maxOutputTokens(for: model, task: task)
            let effectiveMaxTokens = min(maxTokens, modelMaxTokens)
            do {
                AppLogger.log("NVIDIA NIM intentando modelo: \(model) (max_tokens: \(effectiveMaxTokens))")
                let content = try await streamChat(
                    apiKey: apiKey,
                    model: model,
                    messages: messages,
                    temperature: temperature,
                    maxTokens: effectiveMaxTokens,
                    seed: seed
                )
                AppLogger.log("NVIDIA NIM OK con modelo: \(model) (\(content.count) chars)")
                return content
            } catch {
                lastError = error
                AppLogger.error("Modelo \(model) falló", error: error)
            }
        }

        throw NIMError.allModelsFailed(lastError?.localizedDescription ?? "error desconocido")
    }

    // MARK: - Streaming (compatible con OpenAI Python SDK stream=True)

    private func streamChat(
        apiKey: String,
        model: String,
        messages: [[String: String]],
        temperature: Double,
        maxTokens: Int,
        seed: Int?
    ) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "top_p": 1,
            "max_tokens": maxTokens,
            "stream": true
        ]
        if let seed { body["seed"] = seed }

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NIMError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let detail = String(data: errorData, encoding: .utf8) ?? ""
            throw NIMError.decodingFailed("HTTP \(http.statusCode): \(detail)")
        }

        var content = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard
                let data = payload.data(using: .utf8),
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let delta = first["delta"] as? [String: Any],
                let deltaContent = delta["content"] as? String
            else {
                continue
            }

            content += deltaContent
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NIMError.invalidResponse
        }
        return trimmed
    }
}

struct NIMClient: Sendable {
    private let chat = NIMChatClient()

    func generateScript(config: GenerationConfig) async throws -> VideoScript {
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
        - 3-6 escenas según duración (menos escenas = más rápido)
        - primera escena con subtitle_style hook
        """

        let userPrompt = "Crea un reel sobre: \(config.topic)"

        let content = try await chat.complete(
            task: .scriptGeneration,
            messages: [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            temperature: 0.7,
            maxTokens: 2048
        )

        return try parseScriptJSON(content)
    }

    func rankImageQuery(scene: String, candidates: [String]) async throws -> Int {
        guard !candidates.isEmpty else { return 0 }

        let prompt = """
        Escena: \(scene)
        Opciones de imagen (índices 0-\(candidates.count - 1)):
        \(candidates.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n"))
        Responde SOLO con el número del índice de la mejor opción.
        """

        do {
            let content = try await chat.complete(
                task: .imageRanking,
                messages: [["role": "user", "content": prompt]],
                temperature: 0.1,
                maxTokens: 8,
                seed: nil
            )
            if let index = Int(content.trimmingCharacters(in: .whitespacesAndNewlines)),
               candidates.indices.contains(index) {
                return index
            }
        } catch {
            AppLogger.error("Ranking de imagen falló, usando índice 0", error: error)
        }
        return 0
    }

    private func parseScriptJSON(_ content: String) throws -> VideoScript {
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let scriptData = cleaned.data(using: .utf8) else {
            throw NIMError.decodingFailed("contenido vacío")
        }

        do {
            return try JSONDecoder().decode(VideoScript.self, from: scriptData)
        } catch {
            throw NIMError.decodingFailed(error.localizedDescription)
        }
    }
}
