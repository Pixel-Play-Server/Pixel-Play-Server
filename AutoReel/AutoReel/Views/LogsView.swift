import SwiftUI

struct LogsView: View {
    @State private var logText = ""
    @State private var clearedMessage: String?

    var body: some View {
        List {
            Section {
                Text("Los logs se guardan automáticamente y puedes abrirlos desde la app **Archivos** de iOS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label(AppLogger.filesAppPathHint, systemImage: "folder")
                    .font(.footnote)
            }

            Section("Acciones") {
                ShareLink(item: AppLogger.mainLogURL) {
                    Label("Compartir app.log", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    AppLogger.clearLogs()
                    clearedMessage = "Logs borrados"
                    refresh()
                } label: {
                    Label("Borrar logs", systemImage: "trash")
                }

                Button {
                    refresh()
                } label: {
                    Label("Actualizar vista", systemImage: "arrow.clockwise")
                }

                if let clearedMessage {
                    Text(clearedMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Últimas líneas") {
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Logs")
        .onAppear { refresh() }
    }

    private func refresh() {
        logText = AppLogger.recentLogText()
    }
}
