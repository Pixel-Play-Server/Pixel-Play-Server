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
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let script {
                    Group {
                        Text(script.title)
                            .font(.title2.bold())

                        Text("Copy sugerido")
                            .font(.headline)
                        Text(script.caption)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                        Text("Hashtags")
                            .font(.headline)
                        Text(script.hashtags.joined(separator: " "))
                            .foregroundStyle(.blue)
                    }
                }

                ShareLink(item: videoURL) {
                    Label("Compartir video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("Crear otro reel", action: onRegenerate)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}
