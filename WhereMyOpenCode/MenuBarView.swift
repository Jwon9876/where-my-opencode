import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore

    @State private var projects: [Project] = []
    @State private var scanErrorMessage: String?
    @State private var launchStatusMessage: String?
    @State private var launchStatusIsError = false
    @State private var visibleProjectLimit = Self.projectPageSize

    private static let projectPageSize = 5
    private let openCodeLauncher = OpenCodeLauncher()
    private let projectScanner = ProjectScanner()
    private let terminalSessionController = AppleTerminalSessionController()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    recentSection
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

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.headline)

                Spacer()

                if !recentSessions.isEmpty {
                    Text("\(recentSessions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if recentSessions.isEmpty {
                emptyStateText("No recent projects")
            } else {
                ForEach(recentSessions) { session in
                    recentSessionRow(session)
                }
            }
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

    private func recentSessionRow(_ session: TrackedSession) -> some View {
        Button {
            focusOrLaunchOpenCode(for: session.project)
        } label: {
            projectRowContent(
                iconName: "clock",
                title: session.projectName,
                subtitle: openedDateText(for: session)
            )
        }
        .buttonStyle(.plain)
        .help("Open \(session.projectName) in OpenCode\n\(session.projectPath)\n\(session.marker)")
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
        Button {
            focusOrLaunchOpenCode(for: project)
        } label: {
            projectRowContent(
                iconName: "folder",
                title: project.name,
                subtitle: modifiedDateText(for: project)
            )
        }
        .buttonStyle(.plain)
        .help("Open \(project.name) in OpenCode\n\(project.path)")
    }

    private func projectRowContent(iconName: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let launchStatusMessage {
                Text(launchStatusMessage)
                    .font(.caption)
                    .foregroundStyle(launchStatusIsError ? .red : .secondary)
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

    private var recentSessions: [TrackedSession] {
        sessionStore.recentSessions(limit: Self.projectPageSize)
    }

    private func modifiedDateText(for project: Project) -> String {
        guard project.modifiedDate != .distantPast else {
            return "Modified date unavailable"
        }

        return project.modifiedDate.formatted(date: .abbreviated, time: .shortened)
    }

    private func openedDateText(for session: TrackedSession) -> String {
        "Opened \(session.openedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func launchOpenCode(for project: Project) {
        let session = TrackedSession(project: project)
        let settings = settingsStore.settings

        do {
            let launchResult = try openCodeLauncher.launch(project: project, settings: settings, session: session)
            sessionStore.record(session.recordingLaunch(launchResult, terminalApp: settings.terminalApp))
            launchStatusMessage = "Opening \(project.name) in OpenCode."
            launchStatusIsError = false
        } catch {
            launchStatusMessage = error.localizedDescription
            launchStatusIsError = true
        }
    }

    private func focusOrLaunchOpenCode(for project: Project) {
        do {
            if try terminalSessionController.focusFirstRunningSession(
                from: sessionStore.sessions(forProjectPath: project.path)
            ) != nil {
                launchStatusMessage = "Showing existing \(project.name) OpenCode session."
                launchStatusIsError = false
                return
            }
        } catch {
            launchStatusMessage = error.localizedDescription
            launchStatusIsError = true
            return
        }

        launchOpenCode(for: project)
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
