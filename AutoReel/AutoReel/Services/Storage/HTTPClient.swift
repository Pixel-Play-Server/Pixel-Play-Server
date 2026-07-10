import Foundation

enum HTTPClient {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
}

enum TaskTimeoutError: LocalizedError {
    case exceeded(seconds: TimeInterval, step: String)

    var errorDescription: String? {
        switch self {
        case .exceeded(let seconds, let step):
            return "Tiempo agotado (\(Int(seconds))s) en: \(step)"
        }
    }
}

enum TaskTimeout {
    static func run<T>(
        seconds: TimeInterval,
        step: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TaskTimeoutError.exceeded(seconds: seconds, step: step)
            }
            guard let result = try await group.next() else {
                throw TaskTimeoutError.exceeded(seconds: seconds, step: step)
            }
            group.cancelAll()
            return result
        }
    }
}
