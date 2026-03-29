import AppKit
import SwiftUI

final class RenameQueueWindowController: NSWindowController {
    static let shared = RenameQueueWindowController()

    private var queueViewModel: RenameQueueViewModel?

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(aiModelStore: AIModelStore) {
        if window == nil {
            let vm = RenameQueueViewModel(aiModelStore: aiModelStore)
            queueViewModel = vm

            let rootView = RenameQueueView(viewModel: vm)
            let hostingController = NSHostingController(rootView: rootView)

            let queueWindow = NSPanel(contentViewController: hostingController)
            queueWindow.title = "MindReader Rename Queue"
            queueWindow.styleMask.insert(.titled)
            queueWindow.styleMask.insert(.closable)
            queueWindow.styleMask.insert(.resizable)
            queueWindow.styleMask.insert(.miniaturizable)
            queueWindow.isFloatingPanel = true
            queueWindow.hidesOnDeactivate = false
            queueWindow.level = .statusBar
            queueWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            queueWindow.isReleasedWhenClosed = false
            queueWindow.setFrame(NSRect(x: 0, y: 0, width: 660, height: 520), display: true)
            queueWindow.center()

            self.window = queueWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}