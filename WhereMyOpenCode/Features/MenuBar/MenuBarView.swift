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
            MenuBarHeader(rootFolderDisplayValue: viewModel.rootFolderDisplayValue)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LiveSessionsSection(viewModel: viewModel)
                    RecentSection(viewModel: viewModel)
                    AllProjectsSection(viewModel: viewModel)
                }
                .padding(.top, 4)
                .padding(.trailing, Self.scrollBarGutterWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            MenuBarFooter(viewModel: viewModel, sessionStore: sessionStore)
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
}
