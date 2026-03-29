import XCTest
@testable import MindReader

final class RenameExecutionEngineTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
    }

    func testPreviewBuildsPlanWithoutMutatingDisk() throws {
        let source = try makeFile(named: "Scan_0042.pdf")
        let engine = RenameExecutionEngine()
        let proposal = RenameProposal(originalURL: source, proposedFilename: "2025-12-04 - Acme Co - Invoice #1843.pdf")

        let plans = engine.preview(proposals: [proposal])

        XCTAssertEqual(plans.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: plans[0].targetURL.path))
    }

    func testApplyRenamesFilesOnDisk() throws {
        let source = try makeFile(named: "Scan_0042.pdf")
        let engine = RenameExecutionEngine()
        let proposal = RenameProposal(originalURL: source, proposedFilename: "2025-12-04 - Acme Co - Invoice #1843.pdf")

        let records = try engine.apply(plans: engine.preview(proposals: [proposal]))

        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: records[0].renamedURL.path))
    }

    func testRevertRestoresOriginalNames() throws {
        let source = try makeFile(named: "Scan_0042.pdf")
        let engine = RenameExecutionEngine()
        let proposal = RenameProposal(originalURL: source, proposedFilename: "2025-12-04 - Acme Co - Invoice #1843.pdf")

        let records = try engine.apply(plans: engine.preview(proposals: [proposal]))
        try engine.revert(records: records)

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: records[0].renamedURL.path))
    }

    private func makeFile(named name: String) throws -> URL {
        let url = tempDirectoryURL.appendingPathComponent(name)
        try Data("seed".utf8).write(to: url)
        return url
    }
}
