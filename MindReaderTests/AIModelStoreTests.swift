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
}

private struct StubAIModelService: AIModelServing {
    let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func load(model: CuratedModel) async throws {
        if shouldFail { throw StubAIError.failed }
    }

    func unload() async {}
}

private enum StubAIError: Error {
    case failed
}
