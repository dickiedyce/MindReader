import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(appSettingsStore: AppSettingsStore, aiModelStore: AIModelStore) {
        if window == nil {
            let rootView = PreferencesView(appSettingsStore: appSettingsStore, aiModelStore: aiModelStore)
            let hostingController = NSHostingController(rootView: rootView)

            let preferencesWindow = NSWindow(contentViewController: hostingController)
            preferencesWindow.title = "MindReader Preferences"
            preferencesWindow.styleMask.insert(.titled)
            preferencesWindow.styleMask.insert(.closable)
            preferencesWindow.styleMask.insert(.miniaturizable)
            preferencesWindow.styleMask.insert(.resizable)
            preferencesWindow.isReleasedWhenClosed = false
            preferencesWindow.center()

            self.window = preferencesWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
