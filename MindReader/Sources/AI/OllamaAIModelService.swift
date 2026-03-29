import Foundation

/// Concrete AIModelServing implementation that delegates to a local Ollama server.
/// Load verifies the model is present in the Ollama store; unload is a no-op
/// (Ollama manages its own memory). Throws OllamaError.unavailable when the
/// server cannot be reached.
actor OllamaAIModelService: AIModelServing {
    private let ollama: OllamaService

    init(ollama: OllamaService = OllamaService()) {
        self.ollama = ollama
    }

    func load(model: CuratedModel, onProgress: (@Sendable (Double) -> Void)? = nil) async throws {
        guard await ollama.isAvailable() else {
            throw OllamaError.unavailable
        }

        let present = try await ollama.modelIsAvailableLocally(id: model.id)
        if !present {
            try await ollama.downloadModel(id: model.id) { progress in
                onProgress?(progress)
            }
        }
        // Model is now resident in the Ollama store — no additional load step needed.
    }

    func unload() async {
        // Ollama manages its own memory; nothing to release from the client side.
    }

    /// Returns true if the Ollama server is available and the model is resident.
    func isReady(model: CuratedModel) async -> Bool {
        guard await ollama.isAvailable() else { return false }
        return (try? await ollama.modelIsAvailableLocally(id: model.id)) ?? false
    }
}
