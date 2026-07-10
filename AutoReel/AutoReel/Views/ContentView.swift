import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @StateObject private var generator = GeneratorViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !settings.hasRequiredKeys {
                    SettingsView(showDismiss: false)
                } else {
                    mainFlow
                }
            }
            .navigationTitle("AutoReel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink {
                            LogsView()
                        } label: {
                            Image(systemName: "doc.text")
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(showDismiss: true)
                }
            }
        }
        .tint(AppTheme.accent)
    }

    @ViewBuilder
    private var mainFlow: some View {
        switch generator.progress.step {
        case .idle, .failed:
            PromptView(viewModel: generator)
        case .completed:
            if let url = generator.progress.outputURL {
                PreviewView(
                    videoURL: url,
                    script: generator.progress.script,
                    onRegenerate: { generator.reset() }
                )
            } else {
                PromptView(viewModel: generator)
            }
        default:
            GenerationProgressView(progress: generator.progress) {
                generator.cancel()
            }
        }
    }
}
