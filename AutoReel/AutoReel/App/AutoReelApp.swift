import SwiftUI

@main
struct AutoReelApp: App {
    @StateObject private var settings = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}
