import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var nvidiaKey: String = ""
    @Published var elevenLabsKey: String = ""
    @Published var pexelsKey: String = ""
    @Published var unsplashKey: String = ""
    @Published var saveMessage: String?

    var hasRequiredKeys: Bool {
        KeychainService.hasRequiredKeys
    }

    init() {
        loadKeys()
    }

    func loadKeys() {
        nvidiaKey = KeychainService.load(.nvidia) ?? ""
        elevenLabsKey = KeychainService.load(.elevenLabs) ?? ""
        pexelsKey = KeychainService.load(.pexels) ?? ""
        unsplashKey = KeychainService.load(.unsplash) ?? ""
    }

    func saveKeys() {
        do {
            if !nvidiaKey.isEmpty { try KeychainService.save(nvidiaKey, for: .nvidia) }
            if !elevenLabsKey.isEmpty { try KeychainService.save(elevenLabsKey, for: .elevenLabs) }
            if !pexelsKey.isEmpty { try KeychainService.save(pexelsKey, for: .pexels) }
            if !unsplashKey.isEmpty { try KeychainService.save(unsplashKey, for: .unsplash) }
            saveMessage = "API keys guardadas en Keychain"
        } catch {
            saveMessage = error.localizedDescription
        }
    }
}
