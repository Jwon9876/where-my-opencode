import SwiftUI

@MainActor
struct RecentSection: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RadarSectionTitle(title: "Recent")

                Spacer()

                if !viewModel.recentSessions.isEmpty {
                    SectionSignalLabel(kind: .recent, value: "\(viewModel.recentSessions.count)")
                }
            }

            if viewModel.recentSessions.isEmpty {
                EmptyStateText("No recent projects")
            } else {
                ForEach(viewModel.recentSessions) { session in
                    OpenCodeRow(
                        signalKind: .recent,
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
