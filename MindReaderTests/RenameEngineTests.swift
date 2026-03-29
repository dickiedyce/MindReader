import XCTest
@testable import MindReader

final class RenameEngineTests: XCTestCase {
    func testCreatesProposalWithoutMutatingDisk() {
        let formatter = FilenameFormatter(timeZone: TimeZone(secondsFromGMT: 0)!)
        let engine = RenameEngine(formatter: formatter)

        let sourceURL = URL(fileURLWithPath: "/tmp/Scan_0042.pdf")
        let metadata = RenameMetadata(
            date: Date(timeIntervalSince1970: 1764806400),
            datePrecision: .day,
            entity: "Acme Co",
            description: "Invoice #1843"
        )

        let proposal = engine.proposeRename(for: sourceURL, metadata: metadata)

        XCTAssertEqual(proposal.originalURL, sourceURL)
        XCTAssertEqual(proposal.proposedFilename, "2025-12-04 - Acme Co - Invoice #1843.pdf")
    }
}
