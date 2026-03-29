import SwiftUI

@main
struct MindReaderApp: App {
    @StateObject private var appSettingsStore: AppSettingsStore
    @StateObject private var viewModel: MenuBarViewModel

    init() {
        let store = AppSettingsStore()
        _appSettingsStore = StateObject(wrappedValue: store)
        _viewModel = StateObject(wrappedValue: MenuBarViewModel(appSettingsStore: store))
    }

    var body: some Scene {
        MenuBarExtra(
            "MindReader",
            systemImage: "document.badge.gearshape"
        ) {
            MenuBarView(viewModel: viewModel)
                .task { await viewModel.preloadAIModel() }
        }
        .menuBarExtraStyle(.window)
    }
}
