import Foundation
import Combine

@MainActor
final class GeneratorViewModel: ObservableObject {
    @Published var config = GenerationConfig.default
    @Published var selectedVoiceProvider: VoiceProvider = .system
    @Published var selectedSystemVoiceID = SystemVoice.defaultID(for: "es")
    @Published var selectedElevenLabsVoiceID = ElevenLabsVoice.presets[3].id

    let orchestrator = AIOrchestrator()
    private var cancellables = Set<AnyCancellable>()
    private var generationTask: Task<Void, Never>?

    var progress: GenerationProgress { orchestrator.progress }

    init() {
        orchestrator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var isGenerating: Bool {
        let step = orchestrator.progress.step
        return step != .idle && step != .completed && step != .failed
    }

    func generate() {
        guard !config.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        config.voiceProvider = selectedVoiceProvider
        config.voiceID = selectedVoiceProvider == .elevenLabs
            ? selectedElevenLabsVoiceID
            : selectedSystemVoiceID
        generationTask?.cancel()
        generationTask = Task {
            await orchestrator.generate(config: config)
        }
    }

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        orchestrator.reset()
        AppLogger.log("Usuario canceló la generación", level: "WARN")
    }

    func reset() {
        generationTask?.cancel()
        generationTask = nil
        orchestrator.reset()
    }
}
