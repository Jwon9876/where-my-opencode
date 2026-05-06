import SwiftUI

@MainActor
struct RecentSection: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.headline)

                Spacer()

                if !viewModel.recentSessions.isEmpty {
                    Text("\(viewModel.recentSessions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.recentSessions.isEmpty {
                EmptyStateText("No recent projects")
            } else {
                ForEach(viewModel.recentSessions) { session in
                    OpenCodeRow(
                        iconName: "clock",
                        title: session.projectName,
                        subtitle: viewModel.openedDateText(for: session),
                        mainHelpText: MenuBarRowActionPolicy.showOrOpenHelpText,
                        newSessionProject: session.project
                    ) {
                        viewModel.focusOrLaunch(project: session.project)
                    } newSessionAction: { project in
                        viewModel.launchNew(project: project)
                    }
                }
            }
        }
    }
}
