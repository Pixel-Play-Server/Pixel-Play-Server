import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    let showDismiss: Bool

    var body: some View {
        Form {
            Section {
                Text("Las API keys se guardan en el Keychain del iPhone. Nunca las subas a git.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("NVIDIA NIM") {
                SecureField("API Key", text: $settings.nvidiaKey)
                Link("Obtener en build.nvidia.com", destination: URL(string: "https://build.nvidia.com")!)
            }

            Section("ElevenLabs") {
                SecureField("API Key", text: $settings.elevenLabsKey)
                Link("Obtener en elevenlabs.io", destination: URL(string: "https://elevenlabs.io")!)
            }

            Section("Imágenes") {
                SecureField("Pexels API Key", text: $settings.pexelsKey)
                Link("Obtener en pexels.com/api", destination: URL(string: "https://www.pexels.com/api/")!)
                SecureField("Unsplash (opcional)", text: $settings.unsplashKey)
                Link("Obtener en unsplash.com/developers", destination: URL(string: "https://unsplash.com/developers")!)
            }

            Section {
                Button("Guardar keys") {
                    settings.saveKeys()
                }
                if let message = settings.saveMessage {
                    Text(message).font(.footnote)
                }
            }
        }
        .navigationTitle("API Keys")
        .toolbar {
            if showDismiss {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .onAppear { settings.loadKeys() }
    }
}
