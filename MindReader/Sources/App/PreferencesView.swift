import AppKit
import SwiftUI

struct PreferencesView: View {
    enum Tab: String, CaseIterable, Hashable {
        case general
        case aiModel
        case privacy

        var title: String {
            switch self {
            case .general: return "General"
            case .aiModel: return "AI Model"
            case .privacy: return "Privacy"
            }
        }

        var symbolName: String {
            switch self {
            case .general: return "gearshape"
            case .aiModel: return "brain"
            case .privacy: return "lock.shield"
            }
        }
    }

    @ObservedObject var appSettingsStore: AppSettingsStore
    @ObservedObject var aiModelStore: AIModelStore
    @State private var selectedTab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabHeader
            Divider()
            tabContent
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 620, minHeight: 420)
    }

    private var tabHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbolName)
                            .font(.title3)
                        Text(tab.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .aiModel:
            aiModelTab
        case .privacy:
            privacyTab
        }
    }

    private var generalTab: some View {
        Form {
            TextField(
                "Output folder path",
                text: Binding(
                    get: { appSettingsStore.settings.outputDirectoryPath ?? "" },
                    set: { newValue in
                        appSettingsStore.update { settings in
                            settings.outputDirectoryPath = newValue.isEmpty ? nil : newValue
                        }
                    }
                )
            )
            Toggle("Apply Finder tags", isOn: Binding(
                get: { appSettingsStore.settings.enableFinderTags },
                set: { value in
                    appSettingsStore.update { settings in
                        settings.enableFinderTags = value
                    }
                }
            ))
            Toggle("Apply Finder comments", isOn: Binding(
                get: { appSettingsStore.settings.enableFinderComments },
                set: { value in
                    appSettingsStore.update { settings in
                        settings.enableFinderComments = value
                    }
                }
            ))
            Text("Shortcut: \(ShortcutNames.processSelectedFiles)")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var aiModelTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Model Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Selection")
                    .font(.headline)
                ForEach(ModelCatalog.all) { model in
                    Button {
                        aiModelStore.selectedModel = model
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: aiModelStore.selectedModel == model
                                  ? "largecircle.fill.circle"
                                  : "circle")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                Text(model.ramHint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Model Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Status")
                    .font(.headline)
                HStack {
                    lifecycleStatusView
                    Spacer()
                    lifecycleActionButton
                }
            }

            Divider()

            // About
            VStack(alignment: .leading, spacing: 4) {
                Text("About")
                    .font(.headline)
                Text("All AI processing happens on-device. No file content is sent to external servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var lifecycleStatusView: some View {
        switch aiModelStore.lifecycleState {
        case .idle:
            Text("No model loaded")
                .foregroundStyle(.secondary)
        case .downloading(let progress):
            ProgressView(value: progress)
                .frame(maxWidth: 200)
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        case .ready:
            Label("Model ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var lifecycleActionButton: some View {
        switch aiModelStore.lifecycleState {
        case .idle, .error:
            Button("Load Model") {
                Task { await aiModelStore.load() }
            }
            .buttonStyle(.borderedProminent)
        case .ready:
            Button("Unload") {
                Task { await aiModelStore.unload() }
            }
        case .loading, .downloading:
            ProgressView()
                .controlSize(.small)
        }
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionRow(
                title: "Finder Automation",
                status: "Not Requested",
                requestAction: "Request Access"
            ) {
                // Request flow will be wired with actual Finder automation feature.
            }

            Button("Open Privacy Settings") {
                guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else {
                    return
                }
                NSWorkspace.shared.open(url)
            }

            Text("MindReader processes files locally by default. No file content is sent remotely unless explicitly configured.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func permissionRow(title: String, status: String, requestAction: String, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(requestAction, action: action)
        }
    }
}
