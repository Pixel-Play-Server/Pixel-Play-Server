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

    func fetchImage(for scene: ScenePlan, projectID: String) async throws -> ResolvedScene {
        let label = "imagen escena \(scene.id) (\(scene.imageQuery))"
        AppLogger.log("Iniciando \(label)")

        return try await TaskTimeout.run(seconds: 60, step: label) {
            var lastError: Error?

            do {
                let resolved = try await fetchFromPexels(scene: scene, projectID: projectID)
                AppLogger.log("OK \(label) vía Pexels")
                return resolved
            } catch {
                lastError = error
                AppLogger.error("Pexels falló para escena \(scene.id)", error: error)
            }

            if KeychainService.load(.unsplash) != nil {
                do {
                    let resolved = try await fetchFromUnsplash(scene: scene, projectID: projectID)
                    AppLogger.log("OK \(label) vía Unsplash (fallback)")
                    return resolved
                } catch {
                    lastError = error
                    AppLogger.error("Unsplash falló para escena \(scene.id)", error: error)
                }
            }

            throw lastError ?? ImageFetcherError.allSourcesFailed(scene.imageQuery)
        }
    }

    private func fetchFromPexels(scene: ScenePlan, projectID: String) async throws -> ResolvedScene {
        AppLogger.log("Pexels búsqueda: \(scene.imageQuery)")
        let photos = try await pexels.search(query: scene.imageQuery)
        let selected = photos[0]
        AppLogger.log("Pexels descargando foto id \(selected.id)")
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
        AppLogger.log("Unsplash búsqueda: \(scene.imageQuery)")
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
