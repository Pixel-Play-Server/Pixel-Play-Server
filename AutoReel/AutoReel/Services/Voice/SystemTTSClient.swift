import AVFoundation
import Foundation

enum SystemTTSError: LocalizedError {
    case noVoiceAvailable
    case synthesisFailed(String)
    case noAudioGenerated

    var errorDescription: String? {
        switch self {
        case .noVoiceAvailable:
            return "No hay voz del sistema para ese idioma"
        case .synthesisFailed(let detail):
            return "Error generando voz en el iPhone: \(detail)"
        case .noAudioGenerated:
            return "La voz del sistema no generó audio"
        }
    }
}

struct SystemVoice: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String

    static func options(preferredLanguage: String = "es") -> [SystemVoice] {
        let prefix = preferredLanguage.prefix(2).lowercased()
        let installed = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }
            .map { SystemVoice(id: $0.identifier, name: $0.name, language: $0.language) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if !installed.isEmpty {
            return installed
        }

        let fallbackLang = prefix == "es" ? "es-ES" : "en-US"
        return [SystemVoice(id: "__lang__\(fallbackLang)", name: "Automática (\(fallbackLang))", language: fallbackLang)]
    }

    static func defaultID(for language: String) -> String {
        options(preferredLanguage: language).first?.id ?? "__lang__es-ES"
    }
}

struct SystemTTSClient: Sendable {
    func synthesize(text: String, voiceID: String, language: String, projectID: String) async throws -> URL {
        try await Task { @MainActor in
            try await synthesizeOnMain(text: text, voiceID: voiceID, language: language, projectID: projectID)
        }.value
    }

    @MainActor
    private func synthesizeOnMain(
        text: String,
        voiceID: String,
        language: String,
        projectID: String
    ) async throws -> URL {
        let outputURL = MediaCache.projectDirectory(id: projectID).appendingPathComponent("narration.caf")
        try? FileManager.default.removeItem(at: outputURL)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.93
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.15

        if voiceID.hasPrefix("__lang__") {
            let lang = String(voiceID.dropFirst("__lang__".count))
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        } else if let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        } else {
            let lang = language.hasPrefix("es") ? "es-ES" : "en-US"
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        }

        guard utterance.voice != nil else {
            throw SystemTTSError.noVoiceAvailable
        }

        AppLogger.log("Voz del sistema: \(utterance.voice?.name ?? voiceID)")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let synthesizer = AVSpeechSynthesizer()
            var audioFile: AVAudioFile?
            var finished = false

            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

                if pcmBuffer.frameLength == 0 {
                    guard !finished else { return }
                    finished = true
                    if audioFile != nil {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: SystemTTSError.noAudioGenerated)
                    }
                    return
                }

                do {
                    if audioFile == nil {
                        audioFile = try AVAudioFile(forWriting: outputURL, settings: pcmBuffer.format.settings)
                    }
                    try audioFile?.write(from: pcmBuffer)
                } catch {
                    guard !finished else { return }
                    finished = true
                    continuation.resume(throwing: SystemTTSError.synthesisFailed(error.localizedDescription))
                }
            }
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw SystemTTSError.noAudioGenerated
        }

        AppLogger.log("Voz del sistema OK: \(outputURL.lastPathComponent)")
        return outputURL
    }
}
