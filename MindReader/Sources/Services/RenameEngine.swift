import Foundation

protocol RenameProposing {
    func proposeRename(for sourceURL: URL, metadata: RenameMetadata) -> RenameProposal
}

struct RenameMetadata {
    let date: Date?
    let datePrecision: DatePrecision
    let entity: String
    let description: String
}

struct RenameProposal {
    let originalURL: URL
    let proposedFilename: String
}

final class RenameEngine: RenameProposing {
    private let formatter: FilenameFormatter

    init(formatter: FilenameFormatter = FilenameFormatter()) {
        self.formatter = formatter
    }

    func proposeRename(for sourceURL: URL, metadata: RenameMetadata) -> RenameProposal {
        let context = FileNamingContext(
            date: metadata.date,
            datePrecision: metadata.datePrecision,
            entity: metadata.entity,
            description: metadata.description,
            originalExtension: sourceURL.pathExtension
        )

        return RenameProposal(
            originalURL: sourceURL,
            proposedFilename: formatter.format(context: context)
        )
    }
}
