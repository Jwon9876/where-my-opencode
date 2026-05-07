import SwiftUI

@main
struct WhereMyOpenCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(settingsStore: settingsStore, sessionStore: sessionStore)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .accessibilityLabel("Where My OpenCode")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settingsStore: settingsStore)
                .frame(width: 520, height: 360)
        }
    }
}
