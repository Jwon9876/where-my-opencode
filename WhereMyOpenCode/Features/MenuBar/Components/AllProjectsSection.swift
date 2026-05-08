import SwiftUI

@MainActor
struct AllProjectsSection: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        MenuBarSection(
            title: "All Projects",
            signalKind: .project,
            signalValue: projectCountText
        ) {
            content
        }
    }

    private var projectCountText: String? {
        guard !viewModel.projects.isEmpty else {
            return nil
        }

        return "\(viewModel.visibleProjects.count)/\(viewModel.projects.count)"
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasRootFolder {
            EmptyStateText("No projects scanned")
        } else if let scanErrorMessage = viewModel.scanErrorMessage {
            Text(scanErrorMessage)
                .foregroundStyle(.red)
        } else if viewModel.projects.isEmpty {
            EmptyStateText("No projects found")
        } else {
            ForEach(viewModel.visibleProjects) { project in
                OpenCodeRow(
                    signalKind: .project,
                    title: project.name,
                    subtitle: viewModel.modifiedDateText(for: project),
                    mainHelpText: MenuBarRowActionPolicy.showOrOpenHelpText,
                    newSessionProject: project
                ) {
                    viewModel.focusOrLaunch(project: project)
                } newSessionAction: { project in
                    viewModel.launchNew(project: project)
                }
            }

            if viewModel.visibleProjectLimit < viewModel.projects.count {
                Button("Show 5 More") {
                    viewModel.showMoreProjects()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
    }
}
