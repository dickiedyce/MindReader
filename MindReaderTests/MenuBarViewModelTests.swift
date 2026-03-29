import XCTest
@testable import MindReader

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testPrimaryActionShowsNoSelectionMessageWhenFinderSelectionIsEmpty() async {
        let viewModel = MenuBarViewModel(
            appSettingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!, storageKey: #function),
            selectionProvider: StubFinderSelectionProvider(result: .success([])),
            ingestionPipeline: StubFileIngestionPipeline(),
            renameProposer: StubRenameProposer()
        )

        viewModel.triggerPrimaryAction()
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.statusText, "No files selected in Finder")
    }

    func testPrimaryActionBuildsRenameProposalsFromFinderSelection() async {
        let selected = [
            URL(fileURLWithPath: "/tmp/scan_1.pdf"),
            URL(fileURLWithPath: "/tmp/scan_2.pdf")
        ]

        let viewModel = MenuBarViewModel(
            appSettingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!, storageKey: #function),
            selectionProvider: StubFinderSelectionProvider(result: .success(selected)),
            ingestionPipeline: StubFileIngestionPipeline(),
            renameProposer: StubRenameProposer()
        )

        viewModel.triggerPrimaryAction()
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.statusText, "Prepared 2 rename proposal(s)")
        XCTAssertEqual(viewModel.lastProposals.count, 2)
    }

    func testPrimaryActionSurfacesFinderAccessError() async {
        let viewModel = MenuBarViewModel(
            appSettingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!, storageKey: #function),
            selectionProvider: StubFinderSelectionProvider(result: .failure(StubError.failed)),
            ingestionPipeline: StubFileIngestionPipeline(),
            renameProposer: StubRenameProposer()
        )

        viewModel.triggerPrimaryAction()
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.statusText, "Could not read Finder selection")
    }

    func testApplyRenamesProducesRecordsAndClearsProposals() async {
        let selected = [
            URL(fileURLWithPath: "/tmp/scan_1.pdf"),
            URL(fileURLWithPath: "/tmp/scan_2.pdf")
        ]
        let viewModel = MenuBarViewModel(
            appSettingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!, storageKey: #function),
            selectionProvider: StubFinderSelectionProvider(result: .success(selected)),
            ingestionPipeline: StubFileIngestionPipeline(),
            renameProposer: StubRenameProposer(),
            executionEngine: StubRenameExecutionEngine()
        )

        viewModel.triggerPrimaryAction()
        try? await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(viewModel.lastProposals.count, 2)

        await viewModel.applyRenames()

        XCTAssertEqual(viewModel.lastProposals.count, 0)
        XCTAssertEqual(viewModel.lastRecords.count, 2)
        XCTAssertEqual(viewModel.statusText, "Renamed 2 file(s)")
        XCTAssertFalse(viewModel.isProcessing)
    }

    func testRevertRenamesClearsRecordsAndUpdatesStatus() async {
        let selected = [URL(fileURLWithPath: "/tmp/scan_1.pdf")]
        let viewModel = MenuBarViewModel(
            appSettingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!, storageKey: #function),
            selectionProvider: StubFinderSelectionProvider(result: .success(selected)),
            ingestionPipeline: StubFileIngestionPipeline(),
            renameProposer: StubRenameProposer(),
            executionEngine: StubRenameExecutionEngine()
        )

        viewModel.triggerPrimaryAction()
        try? await Task.sleep(for: .milliseconds(20))
        await viewModel.applyRenames()
        XCTAssertEqual(viewModel.lastRecords.count, 1)

        await viewModel.revertRenames()

        XCTAssertEqual(viewModel.lastRecords.count, 0)
        XCTAssertEqual(viewModel.statusText, "Reverted 1 rename(s)")
        XCTAssertFalse(viewModel.isProcessing)
    }

    func testCanApplyRenamesOnlyWhenProposalsExist() async {
        let viewModel = MenuBarViewModel(
            appSettingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!, storageKey: #function),
            selectionProvider: StubFinderSelectionProvider(result: .success([])),
            ingestionPipeline: StubFileIngestionPipeline(),
            renameProposer: StubRenameProposer(),
            executionEngine: StubRenameExecutionEngine()
        )

        XCTAssertFalse(viewModel.canApplyRenames)

        let selected = [URL(fileURLWithPath: "/tmp/scan_1.pdf")]
        let viewModel2 = MenuBarViewModel(
            appSettingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!, storageKey: #function),
            selectionProvider: StubFinderSelectionProvider(result: .success(selected)),
            ingestionPipeline: StubFileIngestionPipeline(),
            renameProposer: StubRenameProposer(),
            executionEngine: StubRenameExecutionEngine()
        )
        viewModel2.triggerPrimaryAction()
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertTrue(viewModel2.canApplyRenames)
    }
}

private enum StubError: Error {
    case failed
}

private struct StubFinderSelectionProvider: FinderSelectionProviding {
    let result: Result<[URL], Error>

    func selectedFileURLs() throws -> [URL] {
        try result.get()
    }
}

private struct StubFileIngestionPipeline: FileIngesting {
    func ingest(fileURL: URL) throws -> IngestedFile {
        let metadata = RenameMetadata(
            date: Date(timeIntervalSince1970: 1764806400),
            datePrecision: .day,
            entity: "Acme Co",
            description: fileURL.deletingPathExtension().lastPathComponent
        )

        return IngestedFile(
            sourceURL: fileURL,
            extractedText: metadata.description,
            renameMetadata: metadata
        )
    }
}

private struct StubRenameProposer: RenameProposing {
    func proposeRename(for sourceURL: URL, metadata: RenameMetadata) -> RenameProposal {
        RenameProposal(
            originalURL: sourceURL,
            proposedFilename: "2025-12-04 — Acme Co — \(metadata.description).pdf"
        )
    }
}

private struct StubRenameExecutionEngine: RenameExecuting {
    func preview(proposals: [RenameProposal]) -> [RenamePlan] {
        proposals.map { proposal in
            let targetURL = proposal.originalURL
                .deletingLastPathComponent()
                .appendingPathComponent(proposal.proposedFilename)
            return RenamePlan(originalURL: proposal.originalURL, targetURL: targetURL)
        }
    }

    func apply(plans: [RenamePlan]) throws -> [RenameRecord] {
        plans.map { RenameRecord(originalURL: $0.originalURL, renamedURL: $0.targetURL) }
    }

    func revert(records: [RenameRecord]) throws {}
}
