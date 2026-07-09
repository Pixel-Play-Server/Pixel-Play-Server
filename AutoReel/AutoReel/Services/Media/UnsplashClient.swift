import Foundation

enum UnsplashError: LocalizedError {
    case missingAPIKey
    case noResults
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Falta la API key de Unsplash"
        case .noResults: return "No se encontraron imágenes en Unsplash"
        case .downloadFailed: return "No se pudo descargar desde Unsplash"
        }
    }
}

struct UnsplashPhoto: Decodable {
    let id: String
    let altDescription: String?
    let urls: URLs

    struct URLs: Decodable {
        let regular: String
        let full: String
    }

    enum CodingKeys: String, CodingKey {
        case id
        case altDescription = "alt_description"
        case urls
    }
}

private struct UnsplashSearchResponse: Decodable {
    let results: [UnsplashPhoto]
}

struct UnsplashClient: Sendable {
    func search(query: String, perPage: Int = 5) async throws -> [UnsplashPhoto] {
        guard let apiKey = KeychainService.load(.unsplash), !apiKey.isEmpty else {
            throw UnsplashError.missingAPIKey
        }

        var components = URLComponents(string: "https://api.unsplash.com/search/photos")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "orientation", value: "portrait")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UnsplashError.noResults
        }

        let decoded = try JSONDecoder().decode(UnsplashSearchResponse.self, from: data)
        guard !decoded.results.isEmpty else { throw UnsplashError.noResults }
        return decoded.results
    }

    func download(photo: UnsplashPhoto) async throws -> Data {
        guard let url = URL(string: photo.urls.regular) else { throw UnsplashError.downloadFailed }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UnsplashError.downloadFailed
        }
        return data
    }
}
