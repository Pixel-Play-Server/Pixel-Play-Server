import SwiftUI

struct GenerationProgressView: View {
    let progress: GenerationProgress
    var onCancel: (() -> Void)?

    private struct StepItem: Identifiable {
        let id: GenerationProgress.Step
        let title: String
        let icon: String
    }

    private var steps: [StepItem] {
        [
            StepItem(id: .warmingUpAI, title: "Conectar IA", icon: "antenna.radiowaves.left.and.right"),
            StepItem(id: .generatingScript, title: "Guion IA", icon: "brain"),
            StepItem(id: .fetchingImages, title: "Imágenes web", icon: "photo.on.rectangle"),
            StepItem(id: .generatingVoice, title: "Voz / narración", icon: "waveform"),
            StepItem(id: .renderingClips, title: "FFmpeg en iPhone", icon: "film")
        ]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.heroGradient.opacity(0.2))
                    .frame(width: 120, height: 120)
                Image(systemName: stepIcon)
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.accent)
                    .modifier(PulseSymbolModifier(isActive: true))
            }

            Text("Generando tu reel")
                .font(.title2.bold())

            Text(progress.message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .animation(.easeInOut, value: progress.message)

            ProgressView(value: progress.progress)
                .tint(AppTheme.accent)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(steps) { item in
                    stepRow(item)
                }
            }
            .appCard()
            .padding(.horizontal)

            if let onCancel {
                Button(role: .destructive) {
                    onCancel()
                } label: {
                    Label("Cancelar", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
        .screenBackground()
    }

    private var stepIcon: String {
        switch progress.step {
        case .warmingUpAI: return "antenna.radiowaves.left.and.right"
        case .generatingScript: return "brain"
        case .fetchingImages: return "photo.on.rectangle"
        case .generatingVoice: return "waveform"
        case .renderingClips, .mergingVideo, .burningSubtitles, .exporting: return "film"
        default: return "wand.and.stars"
        }
    }

    private func stepRow(_ item: StepItem) -> some View {
        let state = stepState(for: item.id)
        return HStack(spacing: 12) {
            Image(systemName: state.icon)
                .foregroundStyle(state.color)
                .frame(width: 22)
            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(state == .current ? .primary : .secondary)
            Spacer()
            if state == .current {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private enum RowState {
        case pending, current, done

        var icon: String {
            switch self {
            case .pending: return "circle"
            case .current: return "circle.dotted"
            case .done: return "checkmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .pending: return .secondary
            case .current: return AppTheme.accent
            case .done: return .green
            }
        }
    }

    private func stepState(for step: GenerationProgress.Step) -> RowState {
        let order: [GenerationProgress.Step] = [
            .warmingUpAI, .generatingScript, .fetchingImages, .generatingVoice, .renderingClips
        ]
        guard let currentIndex = order.firstIndex(of: progress.step),
              let stepIndex = order.firstIndex(of: step) else {
            if progress.step == .completed { return .done }
            return .pending
        }
        if stepIndex < currentIndex { return .done }
        if stepIndex == currentIndex { return .current }
        return .pending
    }
}

private struct PulseSymbolModifier: ViewModifier {
    let isActive: Bool
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.06 : 1.0)
            .animation(
                isActive ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default,
                value: pulsing
            )
            .onAppear { if isActive { pulsing = true } }
    }
}
