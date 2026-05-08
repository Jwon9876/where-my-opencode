import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    typealias ProjectScan = (String?) throws -> [Project]
    typealias RunningSessionsLoad = @Sendable ([TrackedSession]) async throws -> [RunningTerminalSession]
    typealias TrackedSessionsFocus = @Sendable ([TrackedSession]) async throws -> [RunningTerminalSession]
    typealias LiveSessionsFocus = @Sendable ([RunningTerminalSession]) async throws -> [RunningTerminalSession]
    typealias LaunchOpenCode = @Sendable (
        Project,
        AppSettings,
        TrackedSession,
        OpenCodeLaunchFocusPolicy
    ) async throws -> OpenCodeLaunchResult

    static let projectPageSize = 5

    @Published private(set) var projects: [Project] = []
    @Published private(set) var scanErrorMessage: String?
    @Published private(set) var visibleProjectLimit = MenuBarViewModel.projectPageSize
    @Published private(set) var liveSessions: [RunningTerminalSession] = []
    @Published private(set) var status: MenuBarStatus = .idle

    private let settingsStore: SettingsStore
    private let sessionStore: SessionStore
    private let scanProjects: ProjectScan
    private let loadRunningSessions: RunningSessionsLoad
    private let focusTrackedSessions: TrackedSessionsFocus
    private let focusLiveSessions: LiveSessionsFocus
    private let launchOpenCodeInTerminal: LaunchOpenCode

    private var liveRefreshTask: Task<Void, Never>?

    init(
        settingsStore: SettingsStore,
        sessionStore: SessionStore,
        scanProjects: ProjectScan? = nil,
        loadRunningSessions: @escaping RunningSessionsLoad = MenuBarViewModel.loadRunningSessions,
        focusTrackedSessions: @escaping TrackedSessionsFocus = MenuBarViewModel.focusTrackedSessions,
        focusLiveSessions: @escaping LiveSessionsFocus = MenuBarViewModel.focusLiveSessions,
        launchOpenCodeInTerminal: @escaping LaunchOpenCode = MenuBarViewModel.launchOpenCodeInTerminal
    ) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.scanProjects = scanProjects ?? { try ProjectScanner().scan(rootFolderPath: $0) }
        self.loadRunningSessions = loadRunningSessions
        self.focusTrackedSessions = focusTrackedSessions
        self.focusLiveSessions = focusLiveSessions
        self.launchOpenCodeInTerminal = launchOpenCodeInTerminal
    }

    var hasRootFolder: Bool {
        settingsStore.settings.rootFolderPath != nil
    }

    var rootFolderDisplayValue: String {
        settingsStore.settings.rootFolderPath ?? "Choose a root folder in Settings"
    }

    var visibleProjects: [Project] {
        Array(projects.prefix(visibleProjectLimit))
    }

    var recentSessions: [TrackedSession] {
        sessionStore.recentSessions(limit: Self.projectPageSize)
    }

    func showMoreProjects() {
        visibleProjectLimit += Self.projectPageSize
    }

    @discardableResult
    func scanRootAndRefreshLive() -> Task<Void, Never> {
        scanRoot()
        return refreshLive()
    }

    func scanRoot() {
        visibleProjectLimit = Self.projectPageSize

        guard hasRootFolder else {
            projects = []
            scanErrorMessage = nil
            return
        }

        do {
            projects = try scanProjects(settingsStore.settings.rootFolderPath)
            scanErrorMessage = nil
        } catch {
            projects = []
            scanErrorMessage = "Could not scan projects"
        }
    }

    @discardableResult
    func refreshLive() -> Task<Void, Never> {
        liveRefreshTask?.cancel()

        let sessions = sessionStore.sessions
        let task = Task {
            do {
                let runningSessions = try await loadRunningSessions(sessions)

                guard !Task.isCancelled else {
                    return
                }

                liveSessions = runningSessions
                if status.isError {
                    status = .idle
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                liveSessions = []
                status = .error(error.localizedDescription)
            }
        }

        liveRefreshTask = task
        return task
    }

    @discardableResult
    func focusOrLaunch(project: Project) -> Task<Void, Never> {
        let settings = settingsStore.settings
        status = .idle

        return Task {
            do {
                let focusedSessions = try await focusProjectRunningSessions(projectPath: project.path)

                if !focusedSessions.isEmpty {
                    status = .info(MenuBarRowActionPolicy.showingExistingMessage(projectName: project.name))
                    return
                }
            } catch {
                status = .error(error.localizedDescription)
                return
            }

            await launchOpenCode(for: project, settings: settings, focusPolicy: .raiseLaunchedWindow)
        }
    }

    @discardableResult
    func launchNew(project: Project) -> Task<Void, Never> {
        let settings = settingsStore.settings
        status = .info(MenuBarRowActionPolicy.openingNewSessionMessage(projectName: project.name))

        return Task {
            await launchOpenCode(for: project, settings: settings, focusPolicy: .none)
        }
    }

    @discardableResult
    func focusLive(_ liveSession: RunningTerminalSession) -> Task<Void, Never> {
        guard let trackedSession = trackedSession(for: liveSession) else {
            status = .info("Session is no longer running.")
            return refreshLive()
        }

        status = .info(MenuBarRowActionPolicy.showingExistingMessage(projectName: trackedSession.projectName))

        return Task {
            do {
                let focusedSessions = try await focusLiveSessions([liveSession])

                if !focusedSessions.isEmpty {
                    status = .info(MenuBarRowActionPolicy.showingExistingMessage(projectName: trackedSession.projectName))
                    return
                }

                status = .info("Session is no longer running.")
                refreshLive()
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    func modifiedDateText(for project: Project) -> String {
        guard project.modifiedDate != .distantPast else {
            return "Modified date unavailable"
        }

        return project.modifiedDate.formatted(date: .abbreviated, time: .shortened)
    }

    func openedDateText(for session: TrackedSession) -> String {
        "Opened \(session.openedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    func liveSessionTitle(for liveSession: RunningTerminalSession) -> String {
        trackedSession(for: liveSession)?.projectName ?? liveSession.marker
    }

    func liveSessionSubtitle(for liveSession: RunningTerminalSession) -> String {
        if let terminalTabTTY = liveSession.terminalTabTTY {
            return "Running in \(liveSession.terminalApp.displayName): \(terminalTabTTY)"
        }

        return "Running in \(liveSession.terminalApp.displayName)"
    }

    func liveSessionMainHelpText(for liveSession: RunningTerminalSession) -> String {
        let detailText = liveSessionHelpText(for: liveSession)

        guard !detailText.isEmpty else {
            return MenuBarRowActionPolicy.focusLiveSessionHelpText
        }

        return "\(MenuBarRowActionPolicy.focusLiveSessionHelpText)\n\(detailText)"
    }

    func liveSessionNewSessionProject(for liveSession: RunningTerminalSession) -> Project? {
        MenuBarRowActionPolicy.newSessionProject(for: trackedSession(for: liveSession))
    }

    private func trackedSession(for liveSession: RunningTerminalSession) -> TrackedSession? {
        sessionStore.sessions.first { $0.id == liveSession.sessionID }
    }

    private func liveSessionHelpText(for liveSession: RunningTerminalSession) -> String {
        let matchingSession = trackedSession(for: liveSession)
        var values = [
            matchingSession?.projectPath,
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

    private func launchOpenCode(
        for project: Project,
        settings: AppSettings,
        focusPolicy: OpenCodeLaunchFocusPolicy
    ) async {
        let session = TrackedSession(project: project)

        status = .info(MenuBarRowActionPolicy.openingNewSessionMessage(projectName: project.name))

        do {
            let launchResult = try await launchOpenCodeInTerminal(project, settings, session, focusPolicy)
            let recordedSession = session.recordingLaunch(launchResult, terminalApp: settings.terminalApp)

            sessionStore.record(recordedSession)
            upsertLiveSession(recordedSession, launchResult: launchResult)
            refreshLive()
            status = .info(MenuBarRowActionPolicy.openingNewSessionMessage(projectName: project.name))
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func focusProjectRunningSessions(projectPath: String) async throws -> [RunningTerminalSession] {
        let candidateSessions = sessionStore.sessions(forProjectPath: projectPath)

        for session in candidateSessions {
            let focusedSessions = try await focusTrackedSessions([session])
            if let focusedSession = focusedSessions.first {
                return [focusedSession]
            }
        }

        return []
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

    nonisolated private static func loadRunningSessions(
        from sessions: [TrackedSession]
    ) async throws -> [RunningTerminalSession] {
        try await Task.detached(priority: .utility) {
            try TerminalSessionController().runningSessions(from: sessions)
        }.value
    }

    nonisolated private static func focusTrackedSessions(
        _ sessions: [TrackedSession]
    ) async throws -> [RunningTerminalSession] {
        try await Task.detached(priority: .userInitiated) {
            try TerminalSessionController().focusRunningSessions(from: sessions)
        }.value
    }

    nonisolated private static func focusLiveSessions(
        _ sessions: [RunningTerminalSession]
    ) async throws -> [RunningTerminalSession] {
        try await Task.detached(priority: .userInitiated) {
            try TerminalSessionController().focusRunningSessions(sessions)
        }.value
    }

    nonisolated private static func launchOpenCodeInTerminal(
        project: Project,
        settings: AppSettings,
        session: TrackedSession,
        focusPolicy: OpenCodeLaunchFocusPolicy
    ) async throws -> OpenCodeLaunchResult {
        try await Task.detached(priority: .userInitiated) {
            try OpenCodeLauncher().launch(
                project: project,
                settings: settings,
                session: session,
                focusPolicy: focusPolicy
            )
        }.value
    }
}
