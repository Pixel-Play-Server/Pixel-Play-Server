import SwiftUI

@main
struct AutoReelApp: App {
    @StateObject private var settings = SettingsViewModel()

    init() {
        AppLogger.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .onAppear {
                    AppLogger.log("UI ContentView visible")
                }
        }
    }
}
