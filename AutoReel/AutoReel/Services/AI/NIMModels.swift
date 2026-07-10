import Foundation

/// Modelos NVIDIA NIM ordenados por idoneidad para cada tarea.
/// La app prueba en orden hasta que uno responde (streaming evita timeouts).
enum NIMModels {
    enum Task: Sendable {
        case scriptGeneration
        case imageRanking
    }

    /// Guiones JSON: calidad de instrucción + velocidad razonable en móvil.
    static let scriptGeneration: [String] = [
        "meta/llama-3.1-70b-instruct",       // Más rápido que 3.3, buen JSON
        "nvidia/nemotron-mini-4b-instruct",  // Muy rápido
        "meta/llama-3.3-70b-instruct",       // Calidad alta si hay tiempo
        "z-ai/glm-5.2"                       // Máxima calidad (lento)
    ]

    /// Ranking de imágenes: respuesta de 1 dígito, modelo pequeño basta.
    static let imageRanking: [String] = [
        "nvidia/nemotron-mini-4b-instruct",
        "meta/llama-3.1-8b-instruct",
        "meta/llama-3.3-70b-instruct"
    ]

    static func candidates(for task: Task) -> [String] {
        switch task {
        case .scriptGeneration: return scriptGeneration
        case .imageRanking: return imageRanking
        }
    }

    /// Límite de tokens de salida según contexto del modelo (evita HTTP 400 en modelos pequeños).
    static func maxOutputTokens(for model: String, task: Task) -> Int {
        switch task {
        case .scriptGeneration:
            if model.contains("nemotron-mini") { return 896 }
            if model.contains("8b-instruct") { return 1536 }
            return 2048
        case .imageRanking:
            return 16
        }
    }
}
