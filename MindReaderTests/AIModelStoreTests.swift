import XCTest
@testable import MindReader

@MainActor
final class AIModelStoreTests: XCTestCase {
    func testInitialStateIsIdle() {
        let store = AIModelStore(service: StubAIModelService())
        XCTAssertEqual(store.lifecycleState, .idle)
    }

    func testSelectedModelDefaultsToFirstCatalogEntry() {
        let store = AIModelStore(service: StubAIModelService())
        XCTAssertEqual(store.selectedModel, ModelCatalog.all.first)
    }

    func testLoadTransitionsToLoadingThenReady() async {
        let store = AIModelStore(service: StubAIModelService(shouldFail: false))
        await store.load()
        XCTAssertEqual(store.lifecycleState, .ready)
    }

    func testLoadSetsErrorStateWhenServiceFails() async {
        let store = AIModelStore(service: StubAIModelService(shouldFail: true))
        await store.load()
        if case .error = store.lifecycleState { } else {
            XCTFail("Expected .error state, got \(store.lifecycleState)")
        }
    }

    func testUnloadFromReadyReturnsToIdle() async {
        let store = AIModelStore(service: StubAIModelService(shouldFail: false))
        await store.load()
        XCTAssertEqual(store.lifecycleState, .ready)
        await store.unload()
        XCTAssertEqual(store.lifecycleState, .idle)
    }

    func testSelectingDifferentModelUpdatesSelectedModel() {
        let store = AIModelStore(service: StubAIModelService())
        let second = ModelCatalog.all[1]
        store.selectedModel = second
        XCTAssertEqual(store.selectedModel, second)
    }

    func testModelCatalogContainsExpectedModels() {
        XCTAssertEqual(ModelCatalog.all.count, 3)
        XCTAssertEqual(ModelCatalog.all[0].id, "llama3.2:latest")
        XCTAssertEqual(ModelCatalog.all[1].id, "qwen2.5vl:3b")
        XCTAssertEqual(ModelCatalog.all[2].id, "gemma3:4b")
    }

    func testLoadPassesProgressHandlerToServiceAndSetsDownloadingState() async {
        let stub = StubAIModelService(shouldFail: false, progressToReport: 0.4)
        let store = AIModelStore(service: stub)
        var downloadingObserved = false
        let cancellable = store.$lifecycleState.sink { state in
            if case .downloading(let p) = state, p == 0.4 { downloadingObserved = true }
        }
        await store.load()
        // Yield to allow any pending @MainActor tasks to flush
        await Task.yield()
        cancellable.cancel()
        XCTAssertTrue(downloadingObserved, "Expected .downloading(0.4) to be observed during load")
    }
}

private struct StubAIModelService: AIModelServing {
    let shouldFail: Bool
    let progressToReport: Double?

    init(shouldFail: Bool = false, progressToReport: Double? = nil) {
        self.shouldFail = shouldFail
        self.progressToReport = progressToReport
    }

    func load(model: CuratedModel, onProgress: (@Sendable (Double) -> Void)?) async throws {
        if let p = progressToReport { onProgress?(p) }
        if shouldFail { throw StubAIError.failed }
    }

    func unload() async {}
}

private enum StubAIError: Error {
    case failed
}
