import Foundation
import Combine

struct AppSettings: Codable, Equatable {
    var outputDirectoryPath: String?
    var enableFinderTags: Bool
    var enableFinderComments: Bool

    static let `default` = AppSettings(
        outputDirectoryPath: nil,
        enableFinderTags: false,
        enableFinderComments: false
    )
}

final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "MindReader.AppSettings") {
        self.defaults = defaults
        self.storageKey = storageKey
        self.settings = Self.load(defaults: defaults, storageKey: storageKey)
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        var updated = settings
        mutate(&updated)
        settings = updated
        save(updated)
    }

    private func save(_ settings: AppSettings) {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(settings) else {
            return
        }
        defaults.set(encoded, forKey: storageKey)
    }

    private static func load(defaults: UserDefaults, storageKey: String) -> AppSettings {
        guard let data = defaults.data(forKey: storageKey) else {
            return .default
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode(AppSettings.self, from: data)) ?? .default
    }
}
