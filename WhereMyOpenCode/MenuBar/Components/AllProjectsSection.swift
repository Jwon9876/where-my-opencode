import SwiftUI

@MainActor
struct AllProjectsSection: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("All Projects")
                    .font(.headline)

                Spacer()

                if !viewModel.projects.isEmpty {
                    Text("\(viewModel.visibleProjects.count)/\(viewModel.projects.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
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
                    iconName: "folder",
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
