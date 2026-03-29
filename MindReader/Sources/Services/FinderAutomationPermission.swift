import AppKit
import Foundation

/// Tracks and requests Finder Automation permission.
@MainActor
final class FinderAutomationPermission: ObservableObject {
    enum Status: Equatable {
        case unknown
        case granted
        case denied
        case notDetermined
    }

    @Published private(set) var status: Status = .unknown

    func refresh() {
        status = currentStatus()
    }

    func request() {
        // Sending a no-op Apple Event forces the system permission prompt.
        guard let finder = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        ).first else {
            status = .denied
            return
        }

        let target = NSAppleEventDescriptor(processIdentifier: finder.processIdentifier)
        let result = AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            true   // ask user
        )

        switch result {
        case noErr:
            status = .granted
        case OSStatus(errAEEventNotPermitted):
            status = .denied
        default:
            status = .notDetermined
        }
    }

    // MARK: - Private

    private func currentStatus() -> Status {
        guard let finder = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        ).first else {
            return .unknown
        }

        let target = NSAppleEventDescriptor(processIdentifier: finder.processIdentifier)
        let result = AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            false  // don't ask — just probe
        )

        switch result {
        case noErr:
            return .granted
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        default:
            return .unknown
        }
    }
}
