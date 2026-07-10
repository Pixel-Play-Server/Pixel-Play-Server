import Foundation

enum PexelsError: LocalizedError {
    case missingAPIKey
    case noResults
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Falta la API key de Pexels"
        case .noResults: return "No se encontraron imágenes para la búsqueda"
        case .downloadFailed: return "No se pudo descargar la imagen"
        }
    }
}

struct PexelsPhoto: Decodable {
    let id: Int
    let alt: String?
    let src: Source

    struct Source: Decodable {
        let large2x: String
        let portrait: String?
    }
}

private struct PexelsSearchResponse: Decodable {
    let photos: [PexelsPhoto]
}

struct PexelsClient: Sendable {
    func search(query: String, perPage: Int = 5) async throws -> [PexelsPhoto] {
        guard let apiKey = KeychainService.load(.pexels), !apiKey.isEmpty else {
            throw PexelsError.missingAPIKey
        }

        var components = URLComponents(string: "https://api.pexels.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "orientation", value: "portrait")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await HTTPClient.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PexelsError.noResults
        }

        let decoded = try JSONDecoder().decode(PexelsSearchResponse.self, from: data)
        guard !decoded.photos.isEmpty else { throw PexelsError.noResults }
        return decoded.photos
    }

    func download(photo: PexelsPhoto) async throws -> Data {
        let urlString = photo.src.portrait ?? photo.src.large2x
        guard let url = URL(string: urlString) else { throw PexelsError.downloadFailed }

        let (data, response) = try await HTTPClient.session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PexelsError.downloadFailed
        }
        return data
    }
}
