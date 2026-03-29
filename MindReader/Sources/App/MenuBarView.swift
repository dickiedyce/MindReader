import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MindReader")
                .font(.headline)

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button(viewModel.primaryActionTitle) {
                viewModel.triggerPrimaryAction()
            }
            .disabled(!viewModel.canStartProcessing)

            Button(viewModel.secondaryActionTitle) {
                viewModel.stopProcessing()
            }
            .disabled(!viewModel.canStopProcessing)

            if !viewModel.lastProposals.isEmpty {
                Divider()
                ForEach(viewModel.lastProposals, id: \.originalURL) { proposal in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proposal.originalURL.lastPathComponent)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(proposal.proposedFilename)
                                .font(.caption2)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            if viewModel.canApplyRenames {
                Button("Apply \(viewModel.lastProposals.count) Rename(s)") {
                    Task { await viewModel.applyRenames() }
                }
            }

            if viewModel.canRevertRenames {
                Button("Revert \(viewModel.lastRecords.count) Rename(s)") {
                    Task { await viewModel.revertRenames() }
                }
            }

            Divider()

            Button("Open Rename Window...") {
                viewModel.openRenameQueueWindow()
            }

            Button("Preferences...") {
                viewModel.openPreferences()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(minWidth: 280)
    }
}
