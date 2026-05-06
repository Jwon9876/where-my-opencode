import SwiftUI

@MainActor
struct LiveSessionsSection: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Sessions")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.liveSessions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.liveSessions.isEmpty {
                EmptyStateText("No running sessions")
            } else {
                ForEach(viewModel.liveSessions, id: \.sessionID) { liveSession in
                    OpenCodeRow(
                        iconName: "terminal",
                        title: viewModel.liveSessionTitle(for: liveSession),
                        subtitle: viewModel.liveSessionSubtitle(for: liveSession),
                        mainHelpText: viewModel.liveSessionMainHelpText(for: liveSession),
                        newSessionProject: viewModel.liveSessionNewSessionProject(for: liveSession)
                    ) {
                        viewModel.focusLive(liveSession)
                    } newSessionAction: { project in
                        viewModel.launchNew(project: project)
                    }
                }
            }
        }
    }
}
