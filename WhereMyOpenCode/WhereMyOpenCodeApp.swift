import SwiftUI

@main
struct WhereMyOpenCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        MenuBarExtra("Where My OpenCode", systemImage: "terminal") {
            MenuBarView(settingsStore: settingsStore, sessionStore: sessionStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settingsStore: settingsStore)
                .frame(width: 520, height: 360)
        }
    }
}
