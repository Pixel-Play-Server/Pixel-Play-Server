import Foundation

enum VideoDuration: Int, CaseIterable, Identifiable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    var id: Int { rawValue }

    var label: String { "\(rawValue)s" }
}

enum VideoTone: String, CaseIterable, Identifiable {
    case viral
    case educational
    case inspirational
    case professional

    var id: String { rawValue }

    var label: String {
        switch self {
        case .viral: return "Viral"
        case .educational: return "Educativo"
        case .inspirational: return "Inspirador"
        case .professional: return "Profesional"
        }
    }

    var promptHint: String {
        switch self {
        case .viral: return "hook fuerte, frases cortas, ritmo rápido"
        case .educational: return "claro, estructurado, datos concretos"
        case .inspirational: return "emotivo, motivador, storytelling"
        case .professional: return "formal, credibilidad, tono serio"
        }
    }
}

enum VideoFormat: String, CaseIterable, Identifiable {
    case reels
    case square
    case landscape

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reels: return "9:16 Reels"
        case .square: return "1:1 Feed"
        case .landscape: return "16:9"
        }
    }

    var size: (width: Int, height: Int) {
        switch self {
        case .reels: return (1080, 1920)
        case .square: return (1080, 1080)
        case .landscape: return (1920, 1080)
        }
    }
}

enum VoiceProvider: String, CaseIterable, Identifiable {
    case system
    case elevenLabs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Gratis (iPhone)"
        case .elevenLabs: return "ElevenLabs (de pago)"
        }
    }
}

struct GenerationConfig {
    var topic: String
    var duration: VideoDuration
    var tone: VideoTone
    var format: VideoFormat
    var voiceProvider: VoiceProvider
    var voiceID: String
    var language: String

    static let `default` = GenerationConfig(
        topic: "",
        duration: .thirty,
        tone: .viral,
        format: .reels,
        voiceProvider: .system,
        voiceID: SystemVoice.defaultID(for: "es"),
        language: "es"
    )
}
