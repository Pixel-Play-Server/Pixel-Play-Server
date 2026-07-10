import SwiftUI

struct PromptView: View {
    @ObservedObject var viewModel: GeneratorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 10) {
                    Label("Tema del reel", systemImage: "text.quote")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    TextField("Ej: 5 tips de productividad para estudiantes", text: $viewModel.config.topic, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .appCard()

                optionCard(title: "Duración", icon: "clock") {
                    Picker("Duración", selection: $viewModel.config.duration) {
                        ForEach(VideoDuration.allCases) { duration in
                            Text(duration.label).tag(duration)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                optionCard(title: "Tono", icon: "megaphone") {
                    Picker("Tono", selection: $viewModel.config.tone) {
                        ForEach(VideoTone.allCases) { tone in
                            Text(tone.label).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                }

                optionCard(title: "Formato", icon: "rectangle.portrait") {
                    Picker("Formato", selection: $viewModel.config.format) {
                        ForEach(VideoFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                optionCard(title: "Narración", icon: "waveform") {
                    Picker("Motor de voz", selection: $viewModel.selectedVoiceProvider) {
                        ForEach(VoiceProvider.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.selectedVoiceProvider == .system {
                        Picker("Voz del iPhone", selection: $viewModel.selectedSystemVoiceID) {
                            ForEach(SystemVoice.options(preferredLanguage: viewModel.config.language)) { voice in
                                Text(voice.name).tag(voice.id)
                            }
                        }
                        .pickerStyle(.menu)
                        Text("Gratis, sin API key. Se genera en tu iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Voz ElevenLabs", selection: $viewModel.selectedElevenLabsVoiceID) {
                            ForEach(ElevenLabsVoice.presets) { voice in
                                Text(voice.name).tag(voice.id)
                            }
                        }
                        .pickerStyle(.menu)
                        Text("Requiere cuenta de pago en ElevenLabs. Si falla, usa voz del iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = viewModel.progress.error {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.footnote)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    viewModel.generate()
                } label: {
                    Label("Generar video con IA", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.config.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)

                automationNote
            }
            .padding()
        }
        .screenBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "film.stack")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.heroGradient, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("AutoReel")
                        .font(.title2.bold())
                    Text("Todo automático en tu iPhone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("La IA escribe el guion, busca fotos, genera la voz y FFmpeg monta el video.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .appCard()
    }

    private var automationNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pipeline automático")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            flowRow("NVIDIA NIM", "guion y escenas", icon: "brain")
            flowRow("Pexels", "imágenes", icon: "photo.on.rectangle")
            flowRow("iPhone / ElevenLabs", "narración", icon: "waveform")
            flowRow("FFmpeg", "video final", icon: "film")
        }
        .appCard()
    }

    private func flowRow(_ title: String, _ subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func optionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .appCard()
    }
}
