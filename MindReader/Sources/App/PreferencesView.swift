import AppKit
import SwiftUI

struct PreferencesView: View {
    enum Tab: String, CaseIterable, Hashable {
        case general
        case mindReader
        case privacy

        var title: String {
            switch self {
            case .general: return "General"
            case .mindReader: return "MindReader"
            case .privacy: return "Privacy"
            }
        }

        var symbolName: String {
            switch self {
            case .general: return "gearshape"
            case .mindReader: return "doc.text.magnifyingglass"
            case .privacy: return "lock.shield"
            }
        }
    }

    @ObservedObject var appSettingsStore: AppSettingsStore
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
        case .mindReader:
            mindReaderTab
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

    private var mindReaderTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MindReader Parsing Profile")
                .font(.headline)
            Text("This tab will host extraction templates, prompt presets, and rename rules.")
                .foregroundStyle(.secondary)
            Spacer()
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
