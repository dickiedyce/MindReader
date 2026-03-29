import Foundation

protocol RenameMetadataExtracting {
    func metadata(for fileURL: URL) -> RenameMetadata
}

struct RenameMetadataExtractor: RenameMetadataExtracting {
    func metadata(for fileURL: URL) -> RenameMetadata {
        let description = fileURL.deletingPathExtension().lastPathComponent
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let createdAt = attributes?[.creationDate] as? Date

        return RenameMetadata(
            date: createdAt,
            datePrecision: createdAt == nil ? .none : .day,
            entity: "Unknown",
            description: description
        )
    }
}
