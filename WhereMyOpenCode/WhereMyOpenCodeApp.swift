import SwiftUI

@main
struct WhereMyOpenCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Where My OpenCode", systemImage: "terminal") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .frame(width: 520, height: 360)
        }
    }
}

