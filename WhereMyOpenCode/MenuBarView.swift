import AppKit
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Text("Where My OpenCode")
            .font(.headline)

        Divider()

        Section("Recent") {
            Text("No recent projects")
                .foregroundStyle(.secondary)
        }

        Section("Favorites") {
            Text("No favorites")
                .foregroundStyle(.secondary)
        }

        Section("All Projects") {
            Text("No projects scanned")
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("Add Manual Project...") {
            openSettingsWindow()
        }
        .disabled(true)

        Button("Rescan Root Folder") {
            openSettingsWindow()
        }
        .disabled(true)

        Divider()

        Button("Settings...") {
            openSettingsWindow()
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openSettingsWindow() {
        NSApplication.shared.activate()
        NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
