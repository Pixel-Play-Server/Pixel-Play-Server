import SwiftUI

struct GenerationProgressView: View {
    let progress: GenerationProgress
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.purple)

            Text("Generando tu reel")
                .font(.title2.bold())

            Text(progress.message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ProgressView(value: progress.progress)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 10) {
                stepRow("Guion IA", done: progress.progress >= 0.15)
                stepRow("Imágenes web", done: progress.progress >= 0.4)
                stepRow("Voz ElevenLabs", done: progress.progress >= 0.5)
                stepRow("FFmpeg en iPhone", done: progress.progress >= 0.9)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

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
    }

    private func stepRow(_ title: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(title)
            Spacer()
        }
        .font(.subheadline)
    }
}
