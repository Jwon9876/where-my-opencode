import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settingsStore: SettingsStore

    @State private var projects: [Project] = []
    @State private var scanErrorMessage: String?
    @State private var visibleProjectLimit = Self.projectPageSize

    private static let projectPageSize = 5
    private let projectScanner = ProjectScanner()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    emptySection(title: "Recent", message: "No recent projects")
                    emptySection(title: "Favorites", message: "No favorites")
                    allProjectsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 380, height: 480)
        .onAppear(perform: scanRootFolder)
        .onChange(of: settingsStore.settings.rootFolderPath) {
            scanRootFolder()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Where My OpenCode")
                .font(.headline)

            Text(rootFolderDisplayValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var rootFolderDisplayValue: String {
        settingsStore.settings.rootFolderPath ?? "Choose a root folder in Settings"
    }

    private var allProjectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("All Projects")
                    .font(.headline)

                Spacer()

                if !projects.isEmpty {
                    Text("\(visibleProjects.count)/\(projects.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            allProjectsContent
        }
    }

    @ViewBuilder
    private var allProjectsContent: some View {
        if settingsStore.settings.rootFolderPath == nil {
            emptyStateText("No projects scanned")
        } else if let scanErrorMessage {
            Text(scanErrorMessage)
                .foregroundStyle(.red)
        } else if projects.isEmpty {
            emptyStateText("No projects found")
        } else {
            ForEach(visibleProjects) { project in
                projectRow(project)
            }

            if visibleProjectLimit < projects.count {
                Button("Show 5 More") {
                    visibleProjectLimit += Self.projectPageSize
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
    }

    private func emptySection(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            emptyStateText(message)
        }
    }

    private func emptyStateText(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)

                Text(modifiedDateText(for: project))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .help(project.path)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Add Manual Project...") {
                }
                .disabled(true)

                Spacer()

                Button("Rescan Root Folder") {
                    scanRootFolder()
                }
                .disabled(settingsStore.settings.rootFolderPath == nil)
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

    private var visibleProjects: [Project] {
        Array(projects.prefix(visibleProjectLimit))
    }

    private func modifiedDateText(for project: Project) -> String {
        guard project.modifiedDate != .distantPast else {
            return "Modified date unavailable"
        }

        return project.modifiedDate.formatted(date: .abbreviated, time: .shortened)
    }

    private func scanRootFolder() {
        visibleProjectLimit = Self.projectPageSize

        guard settingsStore.settings.rootFolderPath != nil else {
            projects = []
            scanErrorMessage = nil
            return
        }

        do {
            projects = try projectScanner.scan(rootFolderPath: settingsStore.settings.rootFolderPath)
            scanErrorMessage = nil
        } catch {
            projects = []
            scanErrorMessage = "Could not scan projects"
        }
    }
}
