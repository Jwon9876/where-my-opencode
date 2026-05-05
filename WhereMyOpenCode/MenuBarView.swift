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
        }
        .disabled(true)

        Button("Rescan Root Folder") {
        }
        .disabled(true)

        Divider()

        SettingsLink {
            Text("Settings...")
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
