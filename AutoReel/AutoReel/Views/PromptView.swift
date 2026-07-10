import SwiftUI

struct PromptView: View {
    @ObservedObject var viewModel: GeneratorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 8) {
                    Text("¿De qué trata tu reel?")
                        .font(.headline)
                    TextField("Ej: 5 tips de productividad para estudiantes", text: $viewModel.config.topic, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                optionSection(title: "Duración") {
                    Picker("Duración", selection: $viewModel.config.duration) {
                        ForEach(VideoDuration.allCases) { duration in
                            Text(duration.label).tag(duration)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                optionSection(title: "Tono") {
                    Picker("Tono", selection: $viewModel.config.tone) {
                        ForEach(VideoTone.allCases) { tone in
                            Text(tone.label).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                }

                optionSection(title: "Formato") {
                    Picker("Formato", selection: $viewModel.config.format) {
                        ForEach(VideoFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                optionSection(title: "Narración") {
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
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button {
                    viewModel.generate()
                } label: {
                    Label("Generar video con IA", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.config.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)

                automationNote
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Todo automático")
                .font(.title2.bold())
            Text("La IA escribe el guion, descarga fotos de internet, genera la voz y FFmpeg monta el video en tu iPhone.")
                .foregroundStyle(.secondary)
        }
    }

    private var automationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("NVIDIA NIM → guion y escenas", systemImage: "brain")
            Label("Pexels / Unsplash → imágenes", systemImage: "photo.on.rectangle")
            Label("Voz del iPhone (gratis) o ElevenLabs", systemImage: "waveform")
            Label("FFmpeg on-device → export final", systemImage: "film")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func optionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}
