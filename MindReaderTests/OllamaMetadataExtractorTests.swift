import XCTest
@testable import MindReader

final class OllamaMetadataExtractorTests: XCTestCase {
    private let sampleText = "Acme Corp\nInvoice #1843 for consulting services rendered in March 2024."

    func testExtractsEntityDescriptionAndDateFromOllamaResponse() async throws {
        let responseJSON = """
        {
          "model": "llama3.2:latest",
          "response": "{\\"entity\\": \\"Acme Corp\\", \\"description\\": \\"Invoice 1843\\", \\"date\\": \\"2024-03-15\\"}"
        }
        """
        let extractor = OllamaMetadataExtractor(
            session: StubURLSession(responseBody: responseJSON),
            modelID: "llama3.2:latest"
        )

        let metadata = try await extractor.extract(text: sampleText, fileURL: URL(fileURLWithPath: "/tmp/doc.pdf"))

        XCTAssertEqual(metadata.entity, "Acme Corp")
        XCTAssertEqual(metadata.description, "Invoice 1843")
        XCTAssertNotNil(metadata.date)
        XCTAssertEqual(metadata.datePrecision, .day)
    }

    func testHandlesNullDateInOllamaResponse() async throws {
        let responseJSON = """
        {
          "model": "llama3.2:latest",
          "response": "{\\"entity\\": \\"HMRC\\", \\"description\\": \\"Tax return\\", \\"date\\": null}"
        }
        """
        let extractor = OllamaMetadataExtractor(
            session: StubURLSession(responseBody: responseJSON),
            modelID: "llama3.2:latest"
        )

        let metadata = try await extractor.extract(text: sampleText, fileURL: URL(fileURLWithPath: "/tmp/doc.pdf"))

        XCTAssertEqual(metadata.entity, "HMRC")
        XCTAssertEqual(metadata.description, "Tax return")
        XCTAssertNil(metadata.date)
        XCTAssertEqual(metadata.datePrecision, .none)
    }

    func testFallsBackToFilenameMetadataWhenResponseIsMalformed() async throws {
        let responseJSON = """
        {
          "model": "llama3.2:latest",
          "response": "not valid json at all"
        }
        """
        let extractor = OllamaMetadataExtractor(
            session: StubURLSession(responseBody: responseJSON),
            modelID: "llama3.2:latest"
        )
        let fileURL = URL(fileURLWithPath: "/tmp/Invoice March 2024.pdf")

        let metadata = try await extractor.extract(text: sampleText, fileURL: fileURL)

        XCTAssertEqual(metadata.entity, "Unknown")
        XCTAssertEqual(metadata.description, "Invoice March 2024")
    }

    func testThrowsOnHTTPError() async {
        let extractor = OllamaMetadataExtractor(
            session: StubURLSession(statusCode: 500),
            modelID: "llama3.2:latest"
        )
        do {
            _ = try await extractor.extract(text: sampleText, fileURL: URL(fileURLWithPath: "/tmp/doc.pdf"))
            XCTFail("Expected throw")
        } catch OllamaError.httpError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }
}

// MARK: - Stubs (reuse URLSessionProtocol from OllamaServiceTests scope via @testable)

private final class StubURLSession: URLSessionProtocol {
    private let responseBody: String?
    private let statusCode: Int
    private let error: Error?

    init(responseBody: String? = nil, statusCode: Int = 200, error: Error? = nil) {
        self.responseBody = responseBody
        self.statusCode = statusCode
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error { throw error }
        let url = request.url ?? URL(string: "http://localhost")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        let data = responseBody?.data(using: .utf8) ?? Data()
        return (data, response)
    }

    func lines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error> {
        if let error { return AsyncThrowingStream { $0.finish(throwing: error) } }
        let body = responseBody ?? ""
        let lineList = body.components(separatedBy: "\n").filter { !$0.isEmpty }
        return AsyncThrowingStream { continuation in
            for line in lineList { continuation.yield(line) }
            continuation.finish()
        }
    }
}
