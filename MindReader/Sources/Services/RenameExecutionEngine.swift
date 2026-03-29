import Foundation

protocol RenameExecuting {
    func preview(proposals: [RenameProposal]) -> [RenamePlan]
    func apply(plans: [RenamePlan]) throws -> [RenameRecord]
    func revert(records: [RenameRecord]) throws
}

struct RenamePlan {
    let originalURL: URL
    let targetURL: URL
}

struct RenameRecord {
    let originalURL: URL
    let renamedURL: URL
}

enum RenameExecutionError: Error {
    case targetAlreadyExists(URL)
}

final class RenameExecutionEngine: RenameExecuting {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func preview(proposals: [RenameProposal]) -> [RenamePlan] {
        proposals.map { proposal in
            let targetURL = proposal.originalURL
                .deletingLastPathComponent()
                .appendingPathComponent(proposal.proposedFilename)

            return RenamePlan(
                originalURL: proposal.originalURL,
                targetURL: targetURL
            )
        }
    }

    func apply(plans: [RenamePlan]) throws -> [RenameRecord] {
        var records: [RenameRecord] = []

        for plan in plans {
            if fileManager.fileExists(atPath: plan.targetURL.path), plan.targetURL != plan.originalURL {
                throw RenameExecutionError.targetAlreadyExists(plan.targetURL)
            }

            try fileManager.moveItem(at: plan.originalURL, to: plan.targetURL)
            records.append(
                RenameRecord(
                    originalURL: plan.originalURL,
                    renamedURL: plan.targetURL
                )
            )
        }

        return records
    }

    func revert(records: [RenameRecord]) throws {
        for record in records.reversed() {
            if fileManager.fileExists(atPath: record.originalURL.path), record.originalURL != record.renamedURL {
                try fileManager.removeItem(at: record.originalURL)
            }
            try fileManager.moveItem(at: record.renamedURL, to: record.originalURL)
        }
    }
}
