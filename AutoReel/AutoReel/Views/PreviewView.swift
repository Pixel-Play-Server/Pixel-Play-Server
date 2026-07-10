import SwiftUI
import AVKit

struct PreviewView: View {
    let videoURL: URL
    let script: VideoScript?
    let onRegenerate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

                if let script {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(script.title)
                            .font(.title2.bold())

                        Label("Copy sugerido", systemImage: "text.alignleft")
                            .font(.headline)
                        Text(script.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Label("Hashtags", systemImage: "number")
                            .font(.headline)
                        Text(script.hashtags.joined(separator: " "))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .appCard()
                }

                ShareLink(item: videoURL) {
                    Label("Compartir video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Crear otro reel", action: onRegenerate)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .screenBackground()
    }
}
