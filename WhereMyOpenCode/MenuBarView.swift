import AppKit
import SwiftUI

enum MenuBarRowActionPolicy {
    static let showOrOpenHelpText = "Show existing session or open OpenCode"
    static let openNewSessionHelpText = "Open new OpenCode session"
    static let focusLiveSessionHelpText = "Show existing OpenCode session"

    static func showingExistingMessage(projectName: String) -> String {
        "Showing existing \(projectName) OpenCode session."
    }

    static func openingNewSessionMessage(projectName: String) -> String {
        "Opening new \(projectName) OpenCode session."
    }

    static func newSessionProject(for trackedSession: TrackedSession?) -> Project? {
        trackedSession?.project
    }
}

@MainActor
struct MenuBarView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore

    @State private var projects: [Project] = []
    @State private var scanErrorMessage: String?
    @State private var launchStatusMessage: String?
    @State private var launchStatusIsError = false
    @State private var visibleProjectLimit = Self.projectPageSize
    @State private var liveSessions: [RunningTerminalSession] = []
    @State private var liveSessionErrorMessage: String?
    @State private var liveRefreshTask: Task<Void, Never>?

    private static let projectPageSize = 5
    private static let scrollBarGutterWidth: CGFloat = 18
    private let projectScanner = ProjectScanner()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    liveSessionsSection
                    recentSection
                    allProjectsSection
                }
                .padding(.trailing, Self.scrollBarGutterWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 380, height: 480)
        .onAppear(perform: scanRootFolderAndRefreshLiveSessions)
        .onChange(of: settingsStore.settings.rootFolderPath) {
            scanRootFolderAndRefreshLiveSessions()
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

    private var liveSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Sessions")
                    .font(.headline)

                Spacer()

                Text("\(liveSessions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if liveSessions.isEmpty {
                emptyStateText("No running sessions")
            } else {
                ForEach(liveSessions, id: \.sessionID) { liveSession in
                    liveSessionRow(liveSession)
                }
            }
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
        openCodeRow(
            iconName: "clock",
            title: session.projectName,
            subtitle: openedDateText(for: session),
            mainHelpText: MenuBarRowActionPolicy.showOrOpenHelpText,
            newSessionProject: session.project
        ) {
            focusOrLaunchOpenCode(for: session.project)
        }
    }

    private func liveSessionRow(_ liveSession: RunningTerminalSession) -> some View {
        let matchingSession = trackedSession(for: liveSession)
        let title = matchingSession?.projectName ?? liveSession.marker
        let newSessionProject = MenuBarRowActionPolicy.newSessionProject(for: matchingSession)

        return openCodeRow(
            iconName: "terminal",
            title: title,
            subtitle: liveSessionSubtitle(for: liveSession),
            mainHelpText: liveSessionMainHelpText(for: liveSession, trackedSession: matchingSession),
            newSessionProject: newSessionProject
        ) {
            focusLiveSession(liveSession)
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
        openCodeRow(
            iconName: "folder",
            title: project.name,
            subtitle: modifiedDateText(for: project),
            mainHelpText: MenuBarRowActionPolicy.showOrOpenHelpText,
            newSessionProject: project
        ) {
            focusOrLaunchOpenCode(for: project)
        }
    }

    private func openCodeRow(
        iconName: String,
        title: String,
        subtitle: String,
        mainHelpText: String,
        newSessionProject: Project?,
        mainAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Button(action: mainAction) {
                projectRowContent(iconName: iconName, title: title, subtitle: subtitle)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(mainHelpText)

            if let newSessionProject {
                Button {
                    launchNewOpenCode(for: newSessionProject)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(MenuBarRowActionPolicy.openNewSessionHelpText)
                .accessibilityLabel(MenuBarRowActionPolicy.openNewSessionHelpText)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .padding(.trailing, newSessionProject == nil ? 8 : 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
        .contentShape(Rectangle())
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

            if let liveSessionErrorMessage {
                Text(liveSessionErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
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
                    scanRootFolderAndRefreshLiveSessions()
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

    private func liveSessionSubtitle(for liveSession: RunningTerminalSession) -> String {
        if let terminalTabTTY = liveSession.terminalTabTTY {
            return "Running in \(liveSession.terminalApp.displayName): \(terminalTabTTY)"
        }

        return "Running in \(liveSession.terminalApp.displayName)"
    }

    private func liveSessionHelpText(
        for liveSession: RunningTerminalSession,
        trackedSession: TrackedSession?
    ) -> String {
        var values = [
            trackedSession?.projectPath,
            liveSession.terminalApp.displayName,
            liveSession.marker,
            liveSession.terminalCustomTitle,
            liveSession.terminalSessionID,
            liveSession.terminalTabTTY
        ].compactMap { $0 }

        if let terminalWindowID = liveSession.terminalWindowID {
            values.append("Window \(terminalWindowID)")
        }

        return values.joined(separator: "\n")
    }

    private func liveSessionMainHelpText(
        for liveSession: RunningTerminalSession,
        trackedSession: TrackedSession?
    ) -> String {
        let detailText = liveSessionHelpText(for: liveSession, trackedSession: trackedSession)

        guard !detailText.isEmpty else {
            return MenuBarRowActionPolicy.focusLiveSessionHelpText
        }

        return "\(MenuBarRowActionPolicy.focusLiveSessionHelpText)\n\(detailText)"
    }

    private func trackedSession(for liveSession: RunningTerminalSession) -> TrackedSession? {
        sessionStore.sessions.first { $0.id == liveSession.sessionID }
    }

    private func launchOpenCode(for project: Project, settings: AppSettings) async {
        let session = TrackedSession(project: project)

        launchStatusMessage = MenuBarRowActionPolicy.openingNewSessionMessage(projectName: project.name)
        launchStatusIsError = false
        liveSessionErrorMessage = nil

        do {
            let launchResult = try await Self.launchOpenCodeInTerminal(
                project: project,
                settings: settings,
                session: session
            )
            let recordedSession = session.recordingLaunch(launchResult, terminalApp: settings.terminalApp)

            sessionStore.record(recordedSession)
            upsertLiveSession(recordedSession, launchResult: launchResult)
            refreshLiveSessions()
            launchStatusMessage = MenuBarRowActionPolicy.openingNewSessionMessage(projectName: project.name)
            launchStatusIsError = false
            liveSessionErrorMessage = nil
        } catch {
            launchStatusMessage = error.localizedDescription
            launchStatusIsError = true
        }
    }

    private func launchNewOpenCode(for project: Project) {
        let settings = settingsStore.settings

        launchStatusMessage = MenuBarRowActionPolicy.openingNewSessionMessage(projectName: project.name)
        launchStatusIsError = false
        liveSessionErrorMessage = nil

        Task {
            await launchOpenCode(for: project, settings: settings)
        }
    }

    private func focusOrLaunchOpenCode(for project: Project) {
        let candidateSessions = sessionStore.sessions(forProjectPath: project.path)
        let settings = settingsStore.settings

        launchStatusMessage = nil
        launchStatusIsError = false
        liveSessionErrorMessage = nil

        Task {
            do {
                if try await Self.focusFirstRunningSession(from: candidateSessions) != nil {
                    launchStatusMessage = MenuBarRowActionPolicy.showingExistingMessage(projectName: project.name)
                    launchStatusIsError = false
                    liveSessionErrorMessage = nil
                    return
                }
            } catch {
                launchStatusMessage = error.localizedDescription
                launchStatusIsError = true
                return
            }

            await launchOpenCode(for: project, settings: settings)
        }
    }

    private func focusLiveSession(_ liveSession: RunningTerminalSession) {
        guard let trackedSession = trackedSession(for: liveSession) else {
            launchStatusMessage = "Session is no longer running."
            launchStatusIsError = false
            liveSessionErrorMessage = nil
            refreshLiveSessions()
            return
        }

        launchStatusMessage = MenuBarRowActionPolicy.showingExistingMessage(projectName: trackedSession.projectName)
        launchStatusIsError = false
        liveSessionErrorMessage = nil

        Task {
            do {
                if try await Self.focusFirstRunningSession(from: [trackedSession]) != nil {
                    launchStatusMessage = MenuBarRowActionPolicy.showingExistingMessage(projectName: trackedSession.projectName)
                    launchStatusIsError = false
                    liveSessionErrorMessage = nil
                    return
                }

                launchStatusMessage = "Session is no longer running."
                launchStatusIsError = false
                liveSessionErrorMessage = nil
                refreshLiveSessions()
            } catch {
                liveSessionErrorMessage = error.localizedDescription
                launchStatusMessage = nil
                launchStatusIsError = false
            }
        }
    }

    private func scanRootFolderAndRefreshLiveSessions() {
        scanRootFolder()
        refreshLiveSessions()
    }

    private func refreshLiveSessions() {
        liveRefreshTask?.cancel()

        let sessions = sessionStore.sessions

        liveRefreshTask = Task {
            do {
                let runningSessions = try await Self.runningSessions(from: sessions)

                guard !Task.isCancelled else {
                    return
                }

                liveSessions = runningSessions
                liveSessionErrorMessage = nil
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                liveSessions = []
                liveSessionErrorMessage = error.localizedDescription
            }
        }
    }

    private func upsertLiveSession(_ session: TrackedSession, launchResult: OpenCodeLaunchResult) {
        guard launchResult.terminalWindowID != nil
            || launchResult.terminalSessionID != nil
            || launchResult.terminalTabTTY != nil
            || launchResult.terminalCustomTitle != nil else {
            return
        }

        let runningSession = RunningTerminalSession(
            sessionID: session.id,
            marker: session.marker,
            terminalApp: session.terminalApp ?? .appleTerminal,
            terminalWindowID: launchResult.terminalWindowID,
            terminalSessionID: launchResult.terminalSessionID,
            terminalTabTTY: launchResult.terminalTabTTY,
            terminalCustomTitle: launchResult.terminalCustomTitle
        )

        liveSessions.removeAll { $0.sessionID == runningSession.sessionID }
        liveSessions.insert(runningSession, at: 0)
    }

    nonisolated private static func runningSessions(
        from sessions: [TrackedSession]
    ) async throws -> [RunningTerminalSession] {
        try await Task.detached(priority: .utility) {
            try TerminalSessionController().runningSessions(from: sessions)
        }.value
    }

    nonisolated private static func focusFirstRunningSession(
        from sessions: [TrackedSession]
    ) async throws -> RunningTerminalSession? {
        try await Task.detached(priority: .userInitiated) {
            try TerminalSessionController().focusFirstRunningSession(from: sessions)
        }.value
    }

    nonisolated private static func launchOpenCodeInTerminal(
        project: Project,
        settings: AppSettings,
        session: TrackedSession
    ) async throws -> OpenCodeLaunchResult {
        try await Task.detached(priority: .userInitiated) {
            try OpenCodeLauncher().launch(project: project, settings: settings, session: session)
        }.value
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
