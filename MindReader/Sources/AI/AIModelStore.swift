import Foundation

// MARK: - CuratedModel

struct CuratedModel: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let ramHint: String
}

// MARK: - ModelCatalog

enum ModelCatalog {
    static let all: [CuratedModel] = [
        CuratedModel(id: "llama3.2:latest", displayName: "Llama 3.2 (3B)", ramHint: "~4 GB"),
        CuratedModel(id: "qwen2.5vl:3b",   displayName: "Qwen 2.5 VL (3B)", ramHint: "~5 GB"),
        CuratedModel(id: "gemma3:4b",       displayName: "Gemma 3 (4B)", ramHint: "~6 GB"),
    ]
}

// MARK: - AIModelLifecycleState

enum AIModelLifecycleState: Equatable {
    case idle
    case downloading(progress: Double)
    case loading
    case ready
    case error(String)
}

// MARK: - AIModelServing

protocol AIModelServing {
    func load(model: CuratedModel) async throws
    func unload() async
}

// MARK: - NoopAIModelService

struct NoopAIModelService: AIModelServing {
    func load(model: CuratedModel) async throws {}
    func unload() async {}
}

// MARK: - AIModelStore

@MainActor
final class AIModelStore: ObservableObject {
    @Published private(set) var lifecycleState: AIModelLifecycleState = .idle
    @Published var selectedModel: CuratedModel = ModelCatalog.all[0]
    @Published private(set) var ollamaAvailable: Bool = false

    private let service: AIModelServing

    init(service: AIModelServing = OllamaAIModelService()) {
        self.service = service
    }

    /// Call once at app startup. Detects whether Ollama is running and, if so,
    /// preloads the selected model automatically.
    func detectAndPreload() async {
        if let ollamaService = service as? OllamaAIModelService {
            ollamaAvailable = await ollamaService.isReady(model: selectedModel)
        }
        if ollamaAvailable {
            await load()
        }
    }

    func load() async {
        lifecycleState = .loading
        do {
            try await service.load(model: selectedModel)
            lifecycleState = .ready
        } catch OllamaError.unavailable {
            lifecycleState = .error("Ollama not running — start Ollama and try again")
        } catch {
            lifecycleState = .error(error.localizedDescription)
        }
    }

    func unload() async {
        await service.unload()
        lifecycleState = .idle
    }
}
