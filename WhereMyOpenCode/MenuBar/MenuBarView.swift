import AppKit
import SwiftUI

@MainActor
struct MenuBarView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var sessionStore: SessionStore
    @StateObject private var viewModel: MenuBarViewModel

    private static let scrollBarGutterWidth: CGFloat = 18

    init(settingsStore: SettingsStore, sessionStore: SessionStore) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        _viewModel = StateObject(
            wrappedValue: MenuBarViewModel(
                settingsStore: settingsStore,
                sessionStore: sessionStore
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LiveSessionsSection(viewModel: viewModel)
                    RecentSection(viewModel: viewModel)
                    AllProjectsSection(viewModel: viewModel)
                }
                .padding(.trailing, Self.scrollBarGutterWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 380, height: 480)
        .onAppear {
            viewModel.scanRootAndRefreshLive()
        }
        .onChange(of: settingsStore.settings.rootFolderPath) {
            viewModel.scanRootAndRefreshLive()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Where My OpenCode")
                .font(.headline)

            Text(viewModel.rootFolderDisplayValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let statusMessage = viewModel.status.message {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.status.isError ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            if let sessionErrorMessage = sessionStore.lastErrorMessage {
                Text(sessionErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            HStack {
                Button("Add Manual Project...") {
                }
                .disabled(true)

                Spacer()

                Button("Rescan Root Folder") {
                    viewModel.scanRootAndRefreshLive()
                }
                .disabled(!viewModel.hasRootFolder)
            }

            HStack {
                Spacer()

                SettingsLink {
                    Text("Settings...")
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .controlSize(.small)
    }
}
