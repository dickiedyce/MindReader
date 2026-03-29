import XCTest
@testable import MindReader

final class OllamaServiceTests: XCTestCase {
    func testListModelsDecodesSuccessResponse() async throws {
        let json = """
        {
          "models": [
            { "name": "llama3.2:latest", "size": 2019393189 },
            { "name": "gemma3:4b",       "size": 3330786566 }
          ]
        }
        """
        let service = OllamaService(session: StubURLSession(responseBody: json))

        let names = try await service.listAvailableModelIDs()

        XCTAssertEqual(names, ["llama3.2:latest", "gemma3:4b"])
    }

    func testListModelsThrowsOnHTTPError() async {
        let service = OllamaService(session: StubURLSession(statusCode: 500))
        do {
            _ = try await service.listAvailableModelIDs()
            XCTFail("Expected throw")
        } catch OllamaError.httpError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testIsAvailableReturnsTrueWhenServerResponds() async {
        let json = #"{"models":[]}"#
        let service = OllamaService(session: StubURLSession(responseBody: json))
        let available = await service.isAvailable()
        XCTAssertTrue(available)
    }

    func testIsAvailableReturnsFalseOnConnectionError() async {
        let service = OllamaService(session: StubURLSession(error: URLError(.cannotConnectToHost)))
        let available = await service.isAvailable()
        XCTAssertFalse(available)
    }

    func testModelIsAvailableLocallyReturnsTrueWhenInList() async throws {
        let json = """
        {"models":[{"name":"llama3.2:latest","size":2019393189}]}
        """
        let service = OllamaService(session: StubURLSession(responseBody: json))
        let result = try await service.modelIsAvailableLocally(id: "llama3.2:latest")
        XCTAssertTrue(result)
    }

    func testModelIsAvailableLocallyReturnsFalseWhenNotInList() async throws {
        let json = #"{"models":[]}"#
        let service = OllamaService(session: StubURLSession(responseBody: json))
        let result = try await service.modelIsAvailableLocally(id: "llama3.2:latest")
        XCTAssertFalse(result)
    }
}

// MARK: - Stubs

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
}
