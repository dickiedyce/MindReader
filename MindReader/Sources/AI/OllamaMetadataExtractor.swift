import Foundation

// MARK: - Protocol

protocol AIMetadataExtracting {
    func extract(text: String, fileURL: URL) async throws -> RenameMetadata
}

// MARK: - OllamaMetadataExtractor

actor OllamaMetadataExtractor: AIMetadataExtracting {
    private let baseURL: URL
    private let session: URLSessionProtocol
    private let modelID: String

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSessionProtocol = URLSession.shared,
        modelID: String = "llama3.2:latest"
    ) {
        self.baseURL = baseURL
        self.session = session
        self.modelID = modelID
    }

    func extract(text: String, fileURL: URL) async throws -> RenameMetadata {
        let prompt = buildPrompt(text: text)
        let requestBody: [String: Any] = [
            "model": modelID,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]

        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OllamaError.httpError(http.statusCode)
        }

        return parseResponse(data: data, fileURL: fileURL)
    }

    // MARK: - Private

    private func buildPrompt(text: String) -> String {
        """
        Extract metadata from the following document text and return a JSON object with exactly these keys:
        - "entity": the primary organization, person, or sender (string)
        - "description": a short 2-5 word description of the document content (string)
        - "date": the most relevant date in ISO 8601 format "YYYY-MM-DD", or null if not found

        Document text:
        \(text.prefix(2000))

        Respond with only the JSON object, no explanation.
        """
    }

    private func parseResponse(data: Data, fileURL: URL) -> RenameMetadata {
        // Ollama wraps the model's output in a "response" field.
        struct GenerateResponse: Decodable { let response: String }
        struct ExtractedFields: Decodable {
            let entity: String?
            let description: String?
            let date: String?
        }

        let fallbackMetadata = RenameMetadata(
            date: nil,
            datePrecision: .none,
            entity: "Unknown",
            description: fileURL.deletingPathExtension().lastPathComponent
        )

        guard
            let outer = try? JSONDecoder().decode(GenerateResponse.self, from: data),
            let innerData = outer.response.data(using: .utf8),
            let fields = try? JSONDecoder().decode(ExtractedFields.self, from: innerData)
        else {
            return fallbackMetadata
        }

        let entity = fields.entity.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? "Unknown"
        let description = fields.description.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            ?? fileURL.deletingPathExtension().lastPathComponent

        let (date, precision) = parseDate(fields.date)

        return RenameMetadata(date: date, datePrecision: precision, entity: entity, description: description)
    }

    private func parseDate(_ raw: String?) -> (Date?, DatePrecision) {
        guard let raw, !raw.isEmpty, raw != "null" else {
            return (nil, .none)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats: [(String, DatePrecision)] = [
            ("yyyy-MM-dd", .day),
            ("yyyy", .year)
        ]

        for (format, precision) in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw.prefix(format.count).description) {
                return (date, precision)
            }
        }

        return (nil, .none)
    }
}
