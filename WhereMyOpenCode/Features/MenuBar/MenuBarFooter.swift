import AppKit
import SwiftUI

@MainActor
struct MenuBarFooter: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var sessionStore: SessionStore

    var body: some View {
        VStack(spacing: 8) {
            if let statusMessage = viewModel.status.message {
                StatusLine(message: statusMessage, isError: viewModel.status.isError)
            }

            if let sessionErrorMessage = sessionStore.lastErrorMessage {
                StatusLine(message: sessionErrorMessage, isError: true)
            }

            HStack {
                Button {
                } label: {
                    Label("Add Manual Project...", systemImage: "plus")
                }
                .buttonStyle(LocatorButtonStyle(.secondary))
                .disabled(true)

                Spacer()

                Button {
                    viewModel.scanRootAndRefreshLive()
                } label: {
                    Label("Rescan Root Folder", systemImage: "scope")
                }
                .buttonStyle(LocatorButtonStyle(.primary))
                .disabled(!viewModel.hasRootFolder)
            }

            HStack {
                Spacer()

                SettingsLink {
                    Label("Settings...", systemImage: "gearshape")
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
        }
        .controlSize(.small)
        .tint(RadarPalette.signalGreen)
    }
}
