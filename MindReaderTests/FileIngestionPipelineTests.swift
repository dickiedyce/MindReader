import XCTest
@testable import MindReader

final class FileIngestionPipelineTests: XCTestCase {
    func testUsesPrimaryExtractorWhenTextIsAvailable() throws {
        let date = Date(timeIntervalSince1970: 1764806400)
        let pipeline = FileIngestionPipeline(
            documentExtractor: StubDocumentExtractor(result: "Acme Co\nInvoice #1843"),
            ocrExtractor: StubOCRExtractor(result: "OCR should not be used"),
            metadataProvider: StubMetadataProvider(createdDate: date)
        )

        let ingested = try pipeline.ingest(fileURL: URL(fileURLWithPath: "/tmp/scan_42.pdf"))

        XCTAssertEqual(ingested.extractedText, "Acme Co Invoice #1843")
        XCTAssertEqual(ingested.renameMetadata.entity, "Acme Co")
        XCTAssertEqual(ingested.renameMetadata.description, "Invoice #1843")
        XCTAssertEqual(ingested.renameMetadata.date, date)
        XCTAssertEqual(ingested.renameMetadata.datePrecision, .day)
    }

    func testFallsBackToOCRWhenPrimaryTextMissing() throws {
        let pipeline = FileIngestionPipeline(
            documentExtractor: StubDocumentExtractor(result: nil),
            ocrExtractor: StubOCRExtractor(result: "Cafe Receipt\nTotal 12.40"),
            metadataProvider: StubMetadataProvider(createdDate: nil)
        )

        let ingested = try pipeline.ingest(fileURL: URL(fileURLWithPath: "/tmp/receipt.jpg"))

        XCTAssertEqual(ingested.extractedText, "Cafe Receipt Total 12.40")
        XCTAssertEqual(ingested.renameMetadata.entity, "Cafe Receipt")
        XCTAssertEqual(ingested.renameMetadata.description, "Total 12.40")
        XCTAssertEqual(ingested.renameMetadata.datePrecision, .none)
    }

    func testFallsBackToFileNameWhenNoTextFound() throws {
        let pipeline = FileIngestionPipeline(
            documentExtractor: StubDocumentExtractor(result: ""),
            ocrExtractor: StubOCRExtractor(result: nil),
            metadataProvider: StubMetadataProvider(createdDate: nil)
        )

        let ingested = try pipeline.ingest(fileURL: URL(fileURLWithPath: "/tmp/IMG_2847.jpg"))

        XCTAssertEqual(ingested.extractedText, "IMG_2847")
        XCTAssertEqual(ingested.renameMetadata.entity, "Unknown")
        XCTAssertEqual(ingested.renameMetadata.description, "IMG_2847")
        XCTAssertEqual(ingested.renameMetadata.datePrecision, .none)
    }
}

private struct StubDocumentExtractor: DocumentTextExtracting {
    let result: String?

    func extractText(from fileURL: URL) throws -> String? {
        result
    }
}

private struct StubOCRExtractor: OCRTextExtracting {
    let result: String?

    func extractText(from fileURL: URL) throws -> String? {
        result
    }
}

private struct StubMetadataProvider: FileMetadataProviding {
    let createdDate: Date?

    func createdDate(for fileURL: URL) -> Date? {
        createdDate
    }
}
