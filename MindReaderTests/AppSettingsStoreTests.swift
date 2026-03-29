import XCTest
@testable import MindReader

final class AppSettingsStoreTests: XCTestCase {
    private let suiteName = "MindReaderTests.AppSettingsStore"

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testPersistsUpdatedSettings() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = AppSettingsStore(defaults: defaults)

        store.update {
            $0.outputDirectoryPath = "/tmp/output"
            $0.enableFinderTags = true
            $0.enableFinderComments = true
        }

        let reloaded = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.settings.outputDirectoryPath, "/tmp/output")
        XCTAssertTrue(reloaded.settings.enableFinderTags)
        XCTAssertTrue(reloaded.settings.enableFinderComments)
    }

    func testUsesDefaultsWhenNoSavedValueExists() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = AppSettingsStore(defaults: defaults)

        XCTAssertNil(store.settings.outputDirectoryPath)
        XCTAssertFalse(store.settings.enableFinderTags)
        XCTAssertFalse(store.settings.enableFinderComments)
    }
}
