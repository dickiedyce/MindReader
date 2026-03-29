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
    private var currentTask: Task<Void, Never>?

    init(
        appSettingsStore: AppSettingsStore,
        selectionProvider: FinderSelectionProviding = FinderSelectionProvider(),
        ingestionPipeline: FileIngesting = FileIngestionPipeline(),
        renameProposer: RenameProposing = RenameEngine(),
        executionEngine: RenameExecuting = RenameExecutionEngine()
    ) {
        self.appSettingsStore = appSettingsStore
        self.selectionProvider = selectionProvider
        self.ingestionPipeline = ingestionPipeline
        self.renameProposer = renameProposer
        self.executionEngine = executionEngine
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
        PreferencesWindowController.shared.show(appSettingsStore: appSettingsStore)
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

    private func processFinderSelection() {
        isProcessing = true
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

                let proposals = selectedURLs.map { fileURL -> RenameProposal in
                    let ingested = try? self.ingestionPipeline.ingest(fileURL: fileURL)
                    let metadata = ingested?.renameMetadata ?? RenameMetadata(
                        date: nil,
                        datePrecision: .none,
                        entity: "Unknown",
                        description: fileURL.deletingPathExtension().lastPathComponent
                    )
                    return self.renameProposer.proposeRename(for: fileURL, metadata: metadata)
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
}
