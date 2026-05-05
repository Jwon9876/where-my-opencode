import Combine
import Foundation

final class SettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var lastErrorMessage: String?

    let settingsURL: URL

    init(settingsURL: URL = SettingsStore.defaultSettingsURL()) {
        self.settingsURL = settingsURL

        do {
            settings = try Self.loadSettings(from: settingsURL)
            lastErrorMessage = nil
        } catch SettingsStoreError.fileNotFound {
            settings = AppSettings()
            lastErrorMessage = nil
        } catch {
            settings = AppSettings()
            lastErrorMessage = "Could not load settings."
        }
    }

    func setRootFolderPath(_ path: String?) {
        settings.rootFolderPath = normalizedOptionalPath(path)
        saveSettings()
    }

    func setOpenCodePath(_ path: String?) {
        settings.opencodePath = normalizedOptionalPath(path)
        saveSettings()
    }

    func setScanDepth(_ depth: Int) {
        settings.scanDepth = min(max(depth, 1), 5)
        saveSettings()
    }

    func setTerminalApp(_ terminalApp: TerminalApp) {
        settings.terminalApp = terminalApp
        saveSettings()
    }

    private func saveSettings() {
        do {
            try FileManager.default.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not save settings."
        }
    }

    private static func loadSettings(from url: URL) throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SettingsStoreError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    private static func defaultSettingsURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("where-my-opencode", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    private func normalizedOptionalPath(_ path: String?) -> String? {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return (path as NSString).standardizingPath
    }
}

private enum SettingsStoreError: Error {
    case fileNotFound
}
