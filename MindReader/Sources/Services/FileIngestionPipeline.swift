import Foundation
import PDFKit

protocol DocumentTextExtracting {
    func extractText(from fileURL: URL) throws -> String?
}

protocol OCRTextExtracting {
    func extractText(from fileURL: URL) throws -> String?
}

protocol FileMetadataProviding {
    func createdDate(for fileURL: URL) -> Date?
}

protocol FileIngesting {
    func ingest(fileURL: URL) throws -> IngestedFile
}

struct IngestedFile {
    let sourceURL: URL
    let extractedText: String
    let renameMetadata: RenameMetadata
}

struct PlainTextDocumentExtractor: DocumentTextExtracting {
    func extractText(from fileURL: URL) throws -> String? {
        let ext = fileURL.pathExtension.lowercased()
        if ext == "pdf" {
            guard let doc = PDFDocument(url: fileURL) else { return nil }
            return doc.string
        }
        let textExtensions: Set<String> = ["txt", "md", "rtf", "csv", "json", "xml", "yaml", "yml"]
        guard textExtensions.contains(ext) else { return nil }
        return try String(contentsOf: fileURL)
    }
}

struct NoopOCRExtractor: OCRTextExtracting {
    func extractText(from fileURL: URL) throws -> String? {
        nil
    }
}

struct FileAttributesMetadataProvider: FileMetadataProviding {
    func createdDate(for fileURL: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes?[.creationDate] as? Date
    }
}

final class FileIngestionPipeline: FileIngesting {
    private let documentExtractor: DocumentTextExtracting
    private let ocrExtractor: OCRTextExtracting
    private let metadataProvider: FileMetadataProviding

    init(
        documentExtractor: DocumentTextExtracting = PlainTextDocumentExtractor(),
        ocrExtractor: OCRTextExtracting = NoopOCRExtractor(),
        metadataProvider: FileMetadataProviding = FileAttributesMetadataProvider()
    ) {
        self.documentExtractor = documentExtractor
        self.ocrExtractor = ocrExtractor
        self.metadataProvider = metadataProvider
    }

    func ingest(fileURL: URL) throws -> IngestedFile {
        let primaryText = firstNonEmpty(try documentExtractor.extractText(from: fileURL))
        let ocrText = firstNonEmpty(try ocrExtractor.extractText(from: fileURL))
        let fallbackDescription = fileURL.deletingPathExtension().lastPathComponent
        let usedFallback = (primaryText == nil && ocrText == nil)

        let candidateText = primaryText
            ?? ocrText
            ?? fallbackDescription

        let parsedLines = parseMeaningfulLines(candidateText)
        let normalizedText = normalizeText(candidateText)
        let entity = usedFallback ? "Unknown" : (parsedLines.first ?? "Unknown")
        let description = usedFallback ? fallbackDescription : (parsedLines.dropFirst().first ?? fallbackDescription)
        let createdDate = metadataProvider.createdDate(for: fileURL)

        let renameMetadata = RenameMetadata(
            date: createdDate,
            datePrecision: createdDate == nil ? .none : .day,
            entity: entity,
            description: description
        )

        return IngestedFile(
            sourceURL: fileURL,
            extractedText: normalizedText,
            renameMetadata: renameMetadata
        )
    }

    private func firstNonEmpty(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseMeaningfulLines(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
