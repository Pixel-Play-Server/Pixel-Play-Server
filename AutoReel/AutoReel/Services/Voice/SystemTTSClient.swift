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
        let prefix = language.prefix(2).lowercased()
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }

        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced.identifier
        }
        if let first = voices.first {
            return first.identifier
        }
        return prefix == "es" ? "__lang__es-ES" : "__lang__en-US"
    }
}

/// Mantiene vivo el sintetizador hasta que termine (requerido por AVSpeechSynthesizer.write).
@MainActor
private final class LegacySpeechWriter: NSObject {
    private let synthesizer = AVSpeechSynthesizer()

    func write(utterance: AVSpeechUtterance, to outputURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SystemTTSError.noAudioGenerated
        }

        try configureAudioSession()

        let outputURL = MediaCache.projectDirectory(id: projectID).appendingPathComponent("narration.caf")
        try? FileManager.default.removeItem(at: outputURL)

        let utterance = makeUtterance(text: trimmed, voiceID: voiceID, language: language)
        guard utterance.voice != nil else {
            throw SystemTTSError.noVoiceAvailable
        }
        let voiceName = utterance.voice?.name ?? voiceID
        AppLogger.log("Voz del sistema: \(voiceName) | \(trimmed.count) caracteres")

        let started = Date()

        if #available(iOS 17.0, *) {
            let synthesizer = AVSpeechSynthesizer()
            let chunks = splitForSynthesis(trimmed, maxLength: 320)
            AppLogger.log("Sintetizando \(chunks.count) fragmento(s)…")

            if chunks.count == 1 {
                try await synthesizer.write(utterance, to: outputURL)
            } else {
                try await synthesizeChunks(chunks, voiceID: voiceID, language: language, outputURL: outputURL)
            }
        } else {
            let writer = LegacySpeechWriter()
            try await writer.write(utterance: utterance, to: outputURL)
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw SystemTTSError.noAudioGenerated
        }

        let bytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        let elapsed = String(format: "%.1f", Date().timeIntervalSince(started))
        AppLogger.log("Voz del sistema OK: \(outputURL.lastPathComponent) (\(bytes) bytes, \(elapsed)s)")
        return outputURL
    }

    @available(iOS 17.0, *)
    @MainActor
    private func synthesizeChunks(
        _ chunks: [String],
        voiceID: String,
        language: String,
        outputURL: URL
    ) async throws {
        let workDir = outputURL.deletingLastPathComponent()
        var partURLs: [URL] = []

        for (index, chunk) in chunks.enumerated() {
            let partURL = workDir.appendingPathComponent("narration_part_\(index).caf")
            try? FileManager.default.removeItem(at: partURL)
            let utterance = makeUtterance(text: chunk, voiceID: voiceID, language: language)
            let synthesizer = AVSpeechSynthesizer()
            try await synthesizer.write(utterance, to: partURL)
            partURLs.append(partURL)
            AppLogger.log("Fragmento voz \(index + 1)/\(chunks.count) listo")
        }

        try mergeAudioFiles(partURLs, into: outputURL)
        for part in partURLs {
            try? FileManager.default.removeItem(at: part)
        }
    }

    @MainActor
    private func mergeAudioFiles(_ sources: [URL], into outputURL: URL) throws {
        guard let first = sources.first else {
            throw SystemTTSError.noAudioGenerated
        }

        let firstFile = try AVAudioFile(forReading: first)
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: firstFile.fileFormat.settings)
        let bufferCapacity: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: firstFile.processingFormat, frameCapacity: bufferCapacity) else {
            throw SystemTTSError.synthesisFailed("no se pudo crear buffer de audio")
        }

        for source in sources {
            let input = try AVAudioFile(forReading: source)
            while input.framePosition < input.length {
                let framesToRead = min(bufferCapacity, AVAudioFrameCount(input.length - input.framePosition))
                try input.read(into: buffer, frameCount: framesToRead)
                try outputFile.write(from: buffer)
            }
        }
    }

    @MainActor
    private func makeUtterance(text: String, voiceID: String, language: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.12
        utterance.prefersAssistiveTechnologySettings = false

        if voiceID.hasPrefix("__lang__") {
            let lang = String(voiceID.dropFirst("__lang__".count))
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        } else if let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        } else {
            let lang = language.hasPrefix("es") ? "es-ES" : "en-US"
            utterance.voice = AVSpeechSynthesisVoice(language: lang)
        }

        if utterance.voice == nil {
            utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }

        return utterance
    }

    @MainActor
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: [])
    }

    private func splitForSynthesis(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        let separators = CharacterSet(charactersIn: ".!?;\n")
        var chunks: [String] = []
        var current = ""

        for sentence in text.components(separatedBy: separators) {
            let piece = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !piece.isEmpty else { continue }
            let candidate = current.isEmpty ? piece : "\(current). \(piece)"
            if candidate.count <= maxLength {
                current = candidate
            } else {
                if !current.isEmpty { chunks.append(current) }
                if piece.count <= maxLength {
                    current = piece
                } else {
                    var start = piece.startIndex
                    while start < piece.endIndex {
                        let end = piece.index(start, offsetBy: maxLength, limitedBy: piece.endIndex) ?? piece.endIndex
                        chunks.append(String(piece[start..<end]))
                        start = end
                    }
                    current = ""
                }
            }
        }

        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [text] : chunks
    }
}
