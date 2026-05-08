import Combine
import Foundation

final class SettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var lastErrorMessage: String?

    let settingsURL: URL

    private let storage: JSONFileStore<AppSettings>

    init(settingsURL: URL = SettingsStore.defaultSettingsURL()) {
        self.settingsURL = settingsURL
        self.storage = JSONFileStore(url: settingsURL)

        do {
            settings = try storage.load()
            lastErrorMessage = nil
        } catch JSONFileStoreError.fileNotFound {
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

    func setTerminalApp(_ terminalApp: TerminalApp) {
        settings.terminalApp = terminalApp
        saveSettings()
    }

    private func saveSettings() {
        do {
            try storage.save(settings)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not save settings."
        }
    }

    private static func defaultSettingsURL() -> URL {
        AppSupportPaths.file(named: "settings.json")
    }

    private func normalizedOptionalPath(_ path: String?) -> String? {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return (path as NSString).standardizingPath
    }
}
