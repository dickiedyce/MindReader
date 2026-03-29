import Foundation

// MARK: - URLSessionProtocol

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func lines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error>
}

extension URLSession: URLSessionProtocol {
    func lines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error> {
        let (asyncBytes, _) = try await bytes(for: request)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in asyncBytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

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

    // MARK: - Download

    /// Streams download progress (0.0–1.0) for `id` via `/api/pull`.
    /// Calls `onProgress` for each layer-level progress event.
    func downloadModel(id: String, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/pull"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": id, "stream": true])

        let linesStream = try await session.lines(for: request)
        for try await line in linesStream {
            if let progress = OllamaService.parsePullProgress(jsonLine: line) {
                onProgress(progress)
            }
        }
    }

    /// Extracts a 0.0–1.0 progress fraction from a single `/api/pull` ndjson line.
    /// Returns `nil` for lines that carry no progress information (e.g. status-only lines).
    static func parsePullProgress(jsonLine: String) -> Double? {
        guard
            let data = jsonLine.data(using: .utf8),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let total = dict["total"] as? Int, total > 0,
            let completed = dict["completed"] as? Int
        else { return nil }
        return Double(completed) / Double(total)
    }
}
