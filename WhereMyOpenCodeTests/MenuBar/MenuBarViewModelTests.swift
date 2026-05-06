import Foundation
import XCTest
@testable import Where_My_OpenCode

final class MenuBarViewModelTests: TemporaryFileTestCase {
    func testMenuBarRowActionPolicySeparatesFocusAndNewSessionCopy() {
        XCTAssertEqual(MenuBarRowActionPolicy.showOrOpenHelpText, "Show existing session or open OpenCode")
        XCTAssertEqual(MenuBarRowActionPolicy.openNewSessionHelpText, "Open new OpenCode session")
        XCTAssertEqual(
            MenuBarRowActionPolicy.showingExistingMessage(projectName: "Demo"),
            "Showing existing Demo OpenCode session."
        )
        XCTAssertEqual(
            MenuBarRowActionPolicy.openingNewSessionMessage(projectName: "Demo"),
            "Opening new Demo OpenCode session."
        )
    }

    func testMenuBarRowActionPolicyReturnsLiveNewSessionProjectOnlyWhenTracked() {
        let trackedSession = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(MenuBarRowActionPolicy.newSessionProject(for: trackedSession), trackedSession.project)
        XCTAssertNil(MenuBarRowActionPolicy.newSessionProject(for: nil))
    }

    @MainActor
    func testMenuBarViewModelRefreshLiveUpdatesRunningSessions() async throws {
        let stores = try makeStores()
        let trackedSession = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            terminalApp: .appleTerminal
        )
        let runningSession = RunningTerminalSession(
            sessionID: trackedSession.id,
            marker: trackedSession.marker,
            terminalApp: .appleTerminal,
            terminalWindowID: 42,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: trackedSession.terminalTitle
        )
        stores.sessionStore.record(trackedSession)
        let viewModel = MenuBarViewModel(
            settingsStore: stores.settingsStore,
            sessionStore: stores.sessionStore,
            loadRunningSessions: { _ in [runningSession] }
        )

        await viewModel.refreshLive().value

        XCTAssertEqual(viewModel.liveSessions, [runningSession])
        XCTAssertEqual(viewModel.status, .idle)
    }

    @MainActor
    func testMenuBarViewModelFocusOrLaunchShowsExistingSession() async throws {
        let stores = try makeStores()
        let project = Project(name: "Demo", path: "/tmp/Demo")
        let trackedSession = TrackedSession(
            id: "session-123",
            project: project,
            openedAt: Date(timeIntervalSince1970: 300)
        )
        let runningSession = RunningTerminalSession(
            sessionID: trackedSession.id,
            marker: trackedSession.marker,
            terminalApp: .appleTerminal,
            terminalWindowID: 42,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: trackedSession.terminalTitle
        )
        stores.sessionStore.record(trackedSession)
        let viewModel = MenuBarViewModel(
            settingsStore: stores.settingsStore,
            sessionStore: stores.sessionStore,
            focusTrackedSessions: { _ in [runningSession] }
        )

        await viewModel.focusOrLaunch(project: project).value

        XCTAssertEqual(
            viewModel.status,
            .info(MenuBarRowActionPolicy.showingExistingMessage(projectName: project.name))
        )
    }

    @MainActor
    func testMenuBarViewModelLaunchNewRecordsSessionAndRefreshesLiveSessions() async throws {
        let stores = try makeStores()
        let project = Project(name: "Demo", path: "/tmp/Demo")
        stores.settingsStore.setTerminalApp(.iTerm2)
        let viewModel = MenuBarViewModel(
            settingsStore: stores.settingsStore,
            sessionStore: stores.sessionStore,
            loadRunningSessions: { sessions in
                sessions.compactMap { session in
                    guard session.terminalWindowID != nil else {
                        return nil
                    }

                    return RunningTerminalSession(
                        sessionID: session.id,
                        marker: session.marker,
                        terminalApp: session.terminalApp ?? .appleTerminal,
                        terminalWindowID: session.terminalWindowID,
                        terminalSessionID: session.terminalSessionID,
                        terminalTabTTY: session.terminalTabTTY,
                        terminalCustomTitle: session.terminalCustomTitle
                    )
                }
            },
            launchOpenCodeInTerminal: { _, _, session, _ in
                OpenCodeLaunchResult(
                    sessionID: session.id,
                    terminalWindowID: 7,
                    terminalSessionID: "iterm-session-7",
                    terminalTabTTY: "/dev/ttys007",
                    terminalCustomTitle: session.terminalTitle,
                    launchedAt: Date(timeIntervalSince1970: 500)
                )
            }
        )

        await viewModel.launchNew(project: project).value
        await viewModel.refreshLive().value

        let recordedSession = try XCTUnwrap(stores.sessionStore.sessions.first)
        XCTAssertEqual(recordedSession.projectPath, project.path)
        XCTAssertEqual(recordedSession.terminalApp, .iTerm2)
        XCTAssertEqual(recordedSession.terminalWindowID, 7)
        XCTAssertEqual(recordedSession.terminalSessionID, "iterm-session-7")
        XCTAssertEqual(viewModel.liveSessions.map(\.sessionID), [recordedSession.id])
        XCTAssertEqual(
            viewModel.status,
            .info(MenuBarRowActionPolicy.openingNewSessionMessage(projectName: project.name))
        )
    }

    @MainActor
    func testMenuBarViewModelFocusLiveReportsStaleSession() async throws {
        let stores = try makeStores()
        let liveSession = RunningTerminalSession(
            sessionID: "missing-session",
            marker: "WhereMyOpenCode:missing-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 42,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: "OpenCode"
        )
        let viewModel = MenuBarViewModel(
            settingsStore: stores.settingsStore,
            sessionStore: stores.sessionStore,
            loadRunningSessions: { _ in [] }
        )

        await viewModel.focusLive(liveSession).value

        XCTAssertEqual(viewModel.status, .info("Session is no longer running."))
        XCTAssertEqual(viewModel.liveSessions, [])
    }

    private func makeStores() throws -> (settingsStore: SettingsStore, sessionStore: SessionStore) {
        let rootURL = try makeTemporaryDirectory()
        return (
            settingsStore: SettingsStore(settingsURL: rootURL.appendingPathComponent("settings.json")),
            sessionStore: SessionStore(sessionsURL: rootURL.appendingPathComponent("sessions.json"))
        )
    }
}
