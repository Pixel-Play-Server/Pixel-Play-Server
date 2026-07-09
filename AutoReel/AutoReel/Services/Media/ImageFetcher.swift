import Foundation

enum ImageFetcherError: LocalizedError {
    case allSourcesFailed(String)

    var errorDescription: String? {
        switch self {
        case .allSourcesFailed(let query):
            return "No se pudo obtener imagen para: \(query)"
        }
    }
}

struct ImageFetcher: Sendable {
    private let pexels = PexelsClient()
    private let unsplash = UnsplashClient()
    private let nim = NIMClient()

    func fetchImage(
        for scene: ScenePlan,
        projectID: String,
        useAIRanking: Bool = true
    ) async throws -> ResolvedScene {
        var lastError: Error?

        if let resolved = try? await fetchFromPexels(scene: scene, projectID: projectID, useAIRanking: useAIRanking) {
            return resolved
        }
        lastError = ImageFetcherError.allSourcesFailed(scene.imageQuery)

        if KeychainService.load(.unsplash) != nil,
           let resolved = try? await fetchFromUnsplash(scene: scene, projectID: projectID) {
            return resolved
        }

        throw lastError ?? ImageFetcherError.allSourcesFailed(scene.imageQuery)
    }

    private func fetchFromPexels(
        scene: ScenePlan,
        projectID: String,
        useAIRanking: Bool
    ) async throws -> ResolvedScene {
        let photos = try await pexels.search(query: scene.imageQuery)
        let selected: PexelsPhoto

        if useAIRanking, photos.count > 1 {
            let descriptions = photos.map { $0.alt ?? scene.imageQuery }
            let index = try await nim.rankImageQuery(scene: scene.narration, candidates: descriptions)
            selected = photos[index]
        } else {
            selected = photos[0]
        }

        let data = try await pexels.download(photo: selected)
        let filename = "scene_\(scene.id).jpg"
        let localURL = try MediaCache.write(data: data, projectID: projectID, filename: filename)

        return ResolvedScene(
            plan: scene,
            imageURL: URL(string: selected.src.large2x)!,
            localImagePath: localURL.path
        )
    }

    private func fetchFromUnsplash(scene: ScenePlan, projectID: String) async throws -> ResolvedScene {
        let photos = try await unsplash.search(query: scene.imageQuery)
        let selected = photos[0]
        let data = try await unsplash.download(photo: selected)
        let filename = "scene_\(scene.id).jpg"
        let localURL = try MediaCache.write(data: data, projectID: projectID, filename: filename)

        return ResolvedScene(
            plan: scene,
            imageURL: URL(string: selected.urls.regular)!,
            localImagePath: localURL.path
        )
    }
}
