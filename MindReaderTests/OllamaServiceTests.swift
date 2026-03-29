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

    // MARK: - parsePullProgress

    func testParsePullProgressExtractsRatio() {
        let line = #"{"status":"pulling layer","digest":"sha256:abc","total":1024,"completed":512}"#
        let progress = OllamaService.parsePullProgress(jsonLine: line)
        XCTAssertEqual(progress, 0.5)
    }

    func testParsePullProgressReturnsNilForNonProgressLine() {
        let line = #"{"status":"pulling manifest"}"#
        let progress = OllamaService.parsePullProgress(jsonLine: line)
        XCTAssertNil(progress)
    }

    func testParsePullProgressReturnsNilWhenTotalIsZero() {
        let line = #"{"status":"pulling layer","total":0,"completed":0}"#
        let progress = OllamaService.parsePullProgress(jsonLine: line)
        XCTAssertNil(progress)
    }

    // MARK: - downloadModel

    func testDownloadModelCallsProgressHandlerForLayerEvents() async throws {
        let ndjson = """
        {"status":"pulling manifest"}
        {"status":"pulling layer","total":1024,"completed":512}
        {"status":"pulling layer","total":1024,"completed":1024}
        {"status":"success"}
        """
        let service = OllamaService(session: StubURLSession(responseBody: ndjson))
        var received: [Double] = []
        try await service.downloadModel(id: "llama3.2:latest") { received.append($0) }
        XCTAssertEqual(received, [0.5, 1.0])
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

    func lines(for request: URLRequest) async throws -> AsyncThrowingStream<String, Error> {
        if let error { return AsyncThrowingStream { $0.finish(throwing: error) } }
        let body = responseBody ?? ""
        let lines = body.components(separatedBy: "\n").filter { !$0.isEmpty }
        return AsyncThrowingStream { continuation in
            for line in lines { continuation.yield(line) }
            continuation.finish()
        }
    }
}
