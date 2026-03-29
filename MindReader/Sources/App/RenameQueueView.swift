import SwiftUI
import UniformTypeIdentifiers

struct RenameQueueView: View {
    @ObservedObject var viewModel: RenameQueueViewModel
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dropZone

            HStack(spacing: 8) {
                Button("Confirm All") {
                    Task { await viewModel.confirmAll() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Cancel All") {
                    viewModel.cancelAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Clear All") {
                    viewModel.clearAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Files...") {
                    viewModel.pickFiles()
                }
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.lines) { line in
                        lozengeRow(for: line)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .frame(minWidth: 580, minHeight: 420)
    }

    private var showDropArtwork: Bool {
        viewModel.lines.isEmpty
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(isDropTarget ? Color.accentColor : Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6]))
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .frame(height: 74)
            .overlay(
                VStack(spacing: 4) {
                    if showDropArtwork {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.title3)
                    }
                    Text("Drop files here to queue renames")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if showDropArtwork {
                        Text("Each file appears as a lozenge row with an editable name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            )
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) { providers in
                viewModel.handleDrop(providers: providers)
                return true
            }
    }

    private func lozengeRow(for line: RenameQueueLine) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Line 1: source filename + action icons.
            HStack(spacing: 8) {
                Text(line.originalURL.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                statusBadge(line.status)

                iconActionButton(symbol: "eye", tooltip: "Quick Look") {
                    viewModel.quickLook(id: line.id)
                }

                if line.status == .proposed {
                    iconActionButton(symbol: "checkmark.circle.fill", tooltip: "Confirm Rename", prominent: true) {
                        Task { await viewModel.confirmRename(id: line.id) }
                    }
                }

                if line.status == .applied, line.lastRecord != nil {
                    iconActionButton(symbol: "arrow.uturn.backward.circle", tooltip: "Revert Rename") {
                        Task { await viewModel.revertRename(id: line.id) }
                    }
                }
            }

            // Line 2: editable proposed filename.
            TextField("Proposed filename", text: Binding(
                get: { line.proposedFilename },
                set: { viewModel.updateProposedFilename(id: line.id, value: $0) }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(line.status == .applying || line.status == .applied)

            if let error = line.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func iconActionButton(symbol: String, tooltip: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18, height: 18)
                .foregroundStyle(prominent ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    @ViewBuilder
    private func statusBadge(_ status: RenameQueueLineStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .processing: return ("Processing", .orange)
            case .proposed: return ("Proposed", .blue)
            case .applying: return ("Applying", .orange)
            case .applied: return ("Applied", .green)
            case .cancelled: return ("Cancelled", .secondary)
            case .failed: return ("Failed", .red)
            }
        }()

        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
            .foregroundStyle(color)
    }
}