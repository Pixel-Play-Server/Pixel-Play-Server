import Foundation
import Combine

@MainActor
final class GeneratorViewModel: ObservableObject {
    @Published var config = GenerationConfig.default
    @Published var selectedVoiceID = ElevenLabsVoice.presets[3].id

    let orchestrator = AIOrchestrator()
    private var cancellables = Set<AnyCancellable>()

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
        config.voiceID = selectedVoiceID
        Task {
            await orchestrator.generate(config: config)
        }
    }

    func reset() {
        orchestrator.reset()
    }
}
