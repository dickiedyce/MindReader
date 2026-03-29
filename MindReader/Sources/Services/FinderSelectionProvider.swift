import Foundation
import AppKit

protocol FinderSelectionProviding {
    func selectedFileURLs() throws -> [URL]
}

enum FinderSelectionError: Error {
    case appleScriptFailed
    case invalidResult
}

struct FinderSelectionProvider: FinderSelectionProviding {
    func selectedFileURLs() throws -> [URL] {
        let scriptSource = """
        tell application "Finder"
            set selectedItems to selection as alias list
            set selectedPaths to {}
            repeat with selectedItem in selectedItems
                set end of selectedPaths to POSIX path of (selectedItem as alias)
            end repeat
            return selectedPaths
        end tell
        """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            throw FinderSelectionError.appleScriptFailed
        }

        let output = script.executeAndReturnError(&errorInfo)
        if errorInfo != nil {
            throw FinderSelectionError.appleScriptFailed
        }

        guard let descriptors = output.coerce(toDescriptorType: typeAEList) else {
            throw FinderSelectionError.invalidResult
        }

        var urls: [URL] = []
        for index in 1...descriptors.numberOfItems {
            guard let item = descriptors.atIndex(index)?.stringValue else { continue }
            urls.append(URL(fileURLWithPath: item))
        }

        return urls
    }
}
