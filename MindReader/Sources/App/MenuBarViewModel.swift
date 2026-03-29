import AppKit
import Foundation
import Combine

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published private(set) var statusText = "Idle"
    @Published private(set) var lastProposals: [RenameProposal] = []
    @Published private(set) var lastRecords: [RenameRecord] = []

    private let appSettingsStore: AppSettingsStore
    private let selectionProvider: FinderSelectionProviding
    private let ingestionPipeline: FileIngesting
    private let renameProposer: RenameProposing
    private let executionEngine: RenameExecuting
    private let aiModelStore: AIModelStore
    private let aiMetadataExtractor: AIMetadataExtracting?
    private var currentTask: Task<Void, Never>?

    init(
        appSettingsStore: AppSettingsStore,
        selectionProvider: FinderSelectionProviding = FinderSelectionProvider(),
        ingestionPipeline: FileIngesting = FileIngestionPipeline(),
        renameProposer: RenameProposing = RenameEngine(),
        executionEngine: RenameExecuting = RenameExecutionEngine(),
        aiModelStore: AIModelStore? = nil,
        aiMetadataExtractor: AIMetadataExtracting? = nil
    ) {
        self.appSettingsStore = appSettingsStore
        self.selectionProvider = selectionProvider
        self.ingestionPipeline = ingestionPipeline
        self.renameProposer = renameProposer
        self.executionEngine = executionEngine
        self.aiModelStore = aiModelStore ?? AIModelStore()
        self.aiMetadataExtractor = aiMetadataExtractor
    }

    var primaryActionTitle: String {
        isProcessing ? "Processing..." : "Process Selected Files"
    }

    var secondaryActionTitle: String {
        "Stop"
    }

    var canStartProcessing: Bool {
        !isProcessing
    }

    var canStopProcessing: Bool {
        isProcessing
    }

    var canApplyRenames: Bool {
        !isProcessing && !lastProposals.isEmpty
    }

    var canRevertRenames: Bool {
        !isProcessing && !lastRecords.isEmpty
    }

    func triggerPrimaryAction() {
        guard canStartProcessing else {
            return
        }
        processFinderSelection()
    }

    func stopProcessing() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        statusText = "Stopped"
    }

    func openPreferences() {
        PreferencesWindowController.shared.show(appSettingsStore: appSettingsStore, aiModelStore: aiModelStore)
    }

    func preloadAIModel() async {
        await aiModelStore.detectAndPreload()
    }

    func applyRenames() async {
        guard canApplyRenames else { return }
        isProcessing = true
        let plans = executionEngine.preview(proposals: lastProposals)
        do {
            let records = try executionEngine.apply(plans: plans)
            lastProposals = []
            lastRecords = records
            statusText = "Renamed \(records.count) file(s)"
        } catch {
            statusText = "Rename failed: \(error.localizedDescription)"
        }
        isProcessing = false
    }

    func revertRenames() async {
        guard canRevertRenames else { return }
        isProcessing = true
        let records = lastRecords
        do {
            try executionEngine.revert(records: records)
            lastRecords = []
            statusText = "Reverted \(records.count) rename(s)"
        } catch {
            statusText = "Revert failed: \(error.localizedDescription)"
        }
        isProcessing = false
    }

    private func processFinderSelection() {        isProcessing = true
        statusText = "Processing selected files..."
        lastProposals = []

        currentTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let selectedURLs = try self.selectionProvider.selectedFileURLs()
                if Task.isCancelled { return }

                if selectedURLs.isEmpty {
                    self.statusText = "No files selected in Finder"
                    self.isProcessing = false
                    self.currentTask = nil
                    return
                }

                let aiReady = self.aiModelStore.lifecycleState == .ready
                var proposals: [RenameProposal] = []
                for fileURL in selectedURLs {
                    if Task.isCancelled { return }
                    let ingested = try? self.ingestionPipeline.ingest(fileURL: fileURL)
                    let heuristicMetadata = ingested?.renameMetadata ?? RenameMetadata(
                        date: nil,
                        datePrecision: .none,
                        entity: "Unknown",
                        description: fileURL.deletingPathExtension().lastPathComponent
                    )
                    let metadata: RenameMetadata
                    if aiReady, let extractor = self.aiMetadataExtractor ?? self.makeDefaultAIExtractor() {
                        metadata = (try? await extractor.extract(
                            text: ingested?.extractedText ?? "",
                            fileURL: fileURL
                        )) ?? heuristicMetadata
                    } else {
                        metadata = heuristicMetadata
                    }
                    proposals.append(self.renameProposer.proposeRename(for: fileURL, metadata: metadata))
                }

                if Task.isCancelled { return }

                self.lastProposals = proposals
                self.statusText = "Prepared \(proposals.count) rename proposal(s)"
                self.isProcessing = false
                self.currentTask = nil
            } catch {
                self.statusText = "Could not read Finder selection"
                self.isProcessing = false
                self.currentTask = nil
            }
        }
    }

    private func makeDefaultAIExtractor() -> AIMetadataExtracting? {
        OllamaMetadataExtractor(modelID: aiModelStore.selectedModel.id)
    }
}
