import SwiftUI

@main
struct WhereMyOpenCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        MenuBarExtra("Where My OpenCode", systemImage: "terminal") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(settingsStore: settingsStore)
                .frame(width: 520, height: 360)
        }
    }
}
