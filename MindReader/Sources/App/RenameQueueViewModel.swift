import AppKit
import Foundation
import UniformTypeIdentifiers

enum RenameQueueLineStatus: Equatable {
    case processing
    case proposed
    case applying
    case applied
    case cancelled
    case failed
}

struct RenameQueueLine: Identifiable {
    let id: UUID
    let originalURL: URL
    var proposedFilename: String
    var status: RenameQueueLineStatus
    var errorMessage: String?
    var lastRecord: RenameRecord?
}

@MainActor
final class RenameQueueViewModel: ObservableObject {
    @Published private(set) var statusText = "Drop files to start"
    @Published private(set) var lines: [RenameQueueLine] = []

    private let ingestionPipeline: FileIngesting
    private let renameProposer: RenameProposing
    private let executionEngine: RenameExecuting
    private let aiModelStore: AIModelStore
    private let aiMetadataExtractor: AIMetadataExtracting?
    private var processingTasks: [UUID: Task<Void, Never>] = [:]

    init(
        ingestionPipeline: FileIngesting = FileIngestionPipeline(),
        renameProposer: RenameProposing = RenameEngine(),
        executionEngine: RenameExecuting = RenameExecutionEngine(),
        aiModelStore: AIModelStore,
        aiMetadataExtractor: AIMetadataExtracting? = nil
    ) {
        self.ingestionPipeline = ingestionPipeline
        self.renameProposer = renameProposer
        self.executionEngine = executionEngine
        self.aiModelStore = aiModelStore
        self.aiMetadataExtractor = aiMetadataExtractor
    }

    func handleDrop(providers: [NSItemProvider]) {
        let typeID = UTType.fileURL.identifier
        let lock = NSLock()
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(typeID) {
            group.enter()
            provider.loadItem(forTypeIdentifier: typeID, options: nil) { item, _ in
                defer { group.leave() }

                let decodedURL: URL?
                if let data = item as? Data {
                    decodedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    decodedURL = url
                } else if let str = item as? String {
                    decodedURL = URL(string: str)
                } else {
                    decodedURL = nil
                }

                if let url = decodedURL, url.isFileURL {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            Task { @MainActor [weak self] in
                await self?.enqueueDroppedFiles(urls)
            }
        }
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose files to rename"
        if panel.runModal() == .OK {
            Task { @MainActor [weak self] in
                await self?.enqueueDroppedFiles(panel.urls)
            }
        }
    }

    func enqueueDroppedFiles(_ urls: [URL]) async {
        let fileURLs = urls.filter { $0.isFileURL }
        guard !fileURLs.isEmpty else { return }

        for fileURL in fileURLs {
            if lines.contains(where: { $0.originalURL == fileURL }) { continue }

            let id = UUID()
            lines.append(
                RenameQueueLine(
                    id: id,
                    originalURL: fileURL,
                    proposedFilename: fileURL.lastPathComponent,
                    status: .processing,
                    errorMessage: nil,
                    lastRecord: nil
                )
            )

            statusText = "Processing \(lines.count) file(s)..."

            startProcessingLine(id: id, fileURL: fileURL)
        }
    }

    func updateProposedFilename(id: UUID, value: String) {
        updateLine(id: id) { line in
            line.proposedFilename = value
            if line.status == .failed || line.status == .cancelled {
                line.status = .proposed
                line.errorMessage = nil
            }
        }
    }

    func confirmAll() async {
        let ids = lines.filter { $0.status == .proposed }.map(\.id)
        for id in ids {
            await confirmRename(id: id)
        }
    }

    func cancelAll() {
        for (_, task) in processingTasks {
            task.cancel()
        }
        processingTasks.removeAll()

        for index in lines.indices {
            if lines[index].status == .processing || lines[index].status == .applying {
                lines[index].status = .cancelled
                lines[index].errorMessage = "Cancelled"
            }
        }
        statusText = "Cancelled active operations"
    }

    func clearAll() {
        cancelAll()
        lines.removeAll()
        statusText = "Drop files to start"
    }

    func quickLook(id: UUID) {
        guard let line = lines.first(where: { $0.id == id }) else { return }
        let targetURL = line.lastRecord?.renamedURL ?? line.originalURL

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        task.arguments = ["-p", targetURL.path]
        task.standardOutput = nil
        task.standardError = nil
        try? task.run()
    }

    func confirmRename(id: UUID) async {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        guard lines[index].status == .proposed else { return }

        lines[index].status = .applying
        lines[index].errorMessage = nil

        let proposal = RenameProposal(
            originalURL: lines[index].originalURL,
            proposedFilename: lines[index].proposedFilename
        )

        do {
            let plans = executionEngine.preview(proposals: [proposal])
            let records = try executionEngine.apply(plans: plans)
            lines[index].lastRecord = records.first
            lines[index].status = .applied
            processingTasks[id] = nil
            statusText = "Renamed: \(proposal.originalURL.lastPathComponent)"
        } catch {
            lines[index].status = .failed
            lines[index].errorMessage = error.localizedDescription
            processingTasks[id] = nil
            statusText = "Rename failed"
        }
    }

    func revertRename(id: UUID) async {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        guard let record = lines[index].lastRecord else { return }

        do {
            try executionEngine.revert(records: [record])
            lines[index].lastRecord = nil
            lines[index].status = .proposed
            lines[index].errorMessage = nil
            statusText = "Reverted: \(record.renamedURL.lastPathComponent)"
        } catch {
            lines[index].status = .failed
            lines[index].errorMessage = error.localizedDescription
            statusText = "Revert failed"
        }
    }

    private func updateLine(id: UUID, _ update: (inout RenameQueueLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        var line = lines[index]
        update(&line)
        lines[index] = line
    }

    private func startProcessingLine(id: UUID, fileURL: URL) {
        let task = Task { @MainActor [weak self] in
            guard let self else { return }

            if Task.isCancelled {
                self.updateLine(id: id) { line in
                    line.status = .cancelled
                    line.errorMessage = "Cancelled"
                }
                self.processingTasks[id] = nil
                return
            }

            let ingested = try? self.ingestionPipeline.ingest(fileURL: fileURL)
            let heuristicMetadata = ingested?.renameMetadata ?? RenameMetadata(
                date: nil,
                datePrecision: .none,
                entity: "Unknown",
                description: fileURL.deletingPathExtension().lastPathComponent
            )

            var metadata = heuristicMetadata
            if self.aiModelStore.lifecycleState == .ready,
               let extractor = self.aiMetadataExtractor ?? self.makeDefaultAIExtractor(),
               !Task.isCancelled {
                metadata = (try? await extractor.extract(
                    text: ingested?.extractedText ?? "",
                    fileURL: fileURL
                )) ?? heuristicMetadata
            }

            if Task.isCancelled {
                self.updateLine(id: id) { line in
                    line.status = .cancelled
                    line.errorMessage = "Cancelled"
                }
                self.processingTasks[id] = nil
                return
            }

            let proposal = self.renameProposer.proposeRename(for: fileURL, metadata: metadata)
            self.updateLine(id: id) { line in
                line.proposedFilename = proposal.proposedFilename
                line.status = .proposed
                line.errorMessage = nil
            }
            self.processingTasks[id] = nil
            let readyCount = self.lines.filter { $0.status == .proposed }.count
            self.statusText = "Prepared \(readyCount) rename proposal(s)"
        }
        processingTasks[id] = task
    }

    private func makeDefaultAIExtractor() -> AIMetadataExtracting? {
        OllamaMetadataExtractor(modelID: aiModelStore.selectedModel.id)
    }
}