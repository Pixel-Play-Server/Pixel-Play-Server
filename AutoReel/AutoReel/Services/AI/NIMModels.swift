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
        "meta/llama-3.3-70b-instruct",       // Mejor equilibrio calidad/velocidad para JSON
        "meta/llama-3.1-70b-instruct",       // Fallback sólido
        "z-ai/glm-5.2",                      // Muy capaz; streaming evita timeout
        "nvidia/nemotron-mini-4b-instruct"   // Rápido si los grandes fallan
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
}
