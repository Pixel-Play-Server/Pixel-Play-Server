import Foundation

enum SubtitleGenerator {
    static func assFile(for script: VideoScript, width: Int, height: Int) -> String {
        var events: [String] = []
        var currentTime: Double = 0

        for scene in script.scenes {
            let start = formatASSTime(currentTime)
            let end = formatASSTime(currentTime + scene.duration)
            let style = styleName(for: scene.subtitleStyle)
            let text = escapeASS(scene.narration)
            events.append("Dialogue: 0,\(start),\(end),\(style),,0,0,0,,{\\fad(200,200)}\(text)")
            currentTime += scene.duration
        }

        return """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: \(width)
        PlayResY: \(height)
        WrapStyle: 0

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Hook,Arial Black,72,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,4,2,2,40,40,180,1
        Style: Bullet,Arial,56,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,3,1,2,40,40,160,1
        Style: Normal,Arial,52,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,3,1,2,40,40,140,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        \(events.joined(separator: "\n"))
        """
    }

    private static func styleName(for style: SubtitleStyle) -> String {
        switch style {
        case .hook: return "Hook"
        case .bullet: return "Bullet"
        case .normal: return "Normal"
        }
    }

    private static func formatASSTime(_ seconds: Double) -> String {
        let total = max(0, seconds)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let secs = Int(total) % 60
        let centis = Int((total - floor(total)) * 100)
        return String(format: "%01d:%02d:%02d.%02d", hours, minutes, secs, centis)
    }

    private static func escapeASS(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\N")
    }
}
