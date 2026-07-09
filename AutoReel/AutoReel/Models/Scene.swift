import Foundation

enum SubtitleStyle: String, Codable {
    case hook
    case bullet
    case normal
}

enum SceneTransition: String, Codable {
    case fade
    case slideleft
    case slideright
    case wipeleft
    case none
}

struct ScenePlan: Codable, Identifiable, Sendable {
    let id: Int
    let duration: Double
    let narration: String
    let imageQuery: String
    let subtitleStyle: SubtitleStyle
    let transition: SceneTransition

    enum CodingKeys: String, CodingKey {
        case id
        case duration
        case narration
        case imageQuery = "image_query"
        case subtitleStyle = "subtitle_style"
        case transition
    }
}

struct VideoScript: Codable, Sendable {
    let title: String
    let duration: Int
    let scenes: [ScenePlan]
    let voiceID: String?
    let musicMood: String?
    let hashtags: [String]
    let caption: String

    enum CodingKeys: String, CodingKey {
        case title
        case duration
        case scenes
        case voiceID = "voice_id"
        case musicMood = "music_mood"
        case hashtags
        case caption
    }

    var fullNarration: String {
        scenes.map(\.narration).joined(separator: " ")
    }
}

struct ResolvedScene: Identifiable, Sendable {
    var id: Int { plan.id }
    let plan: ScenePlan
    let imageURL: URL
    let localImagePath: String
}

struct GenerationProgress: Sendable {
    enum Step: String, Sendable {
        case idle
        case generatingScript
        case fetchingImages
        case generatingVoice
        case fetchingMusic
        case renderingClips
        case mergingVideo
        case burningSubtitles
        case exporting
        case completed
        case failed
    }

    var step: Step = .idle
    var progress: Double = 0
    var message: String = ""
    var script: VideoScript?
    var outputURL: URL?
    var error: String?
}
