import Foundation

// MARK: - URLSessionProtocol

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - OllamaError

enum OllamaError: Error, Equatable {
    case httpError(Int)
    case unavailable
}

// MARK: - Response models

private struct OllamaModelsResponse: Decodable {
    struct ModelEntry: Decodable {
        let name: String
    }
    let models: [ModelEntry]
}

// MARK: - OllamaService

actor OllamaService {
    private let baseURL: URL
    private let session: URLSessionProtocol

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Returns true if the Ollama server is reachable.
    func isAvailable() async -> Bool {
        do {
            _ = try await listAvailableModelIDs()
            return true
        } catch {
            return false
        }
    }

    /// Returns the model IDs currently present in the local Ollama store.
    func listAvailableModelIDs() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OllamaError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        return decoded.models.map(\.name)
    }

    /// Returns true if `id` is already present in the local Ollama store.
    func modelIsAvailableLocally(id: String) async throws -> Bool {
        let ids = try await listAvailableModelIDs()
        return ids.contains(id)
    }
}
