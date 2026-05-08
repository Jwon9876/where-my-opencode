import Foundation
import XCTest
@testable import Where_My_OpenCode

final class MenuBarViewModelTests: TemporaryFileTestCase {
    actor FocusRequestRecorder {
        private var values: [[String]] = []

        func append(_ request: [String]) {
            values.append(request)
        }

        func snapshot() -> [[String]] {
            values
        }
    }

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
    func testMenuBarViewModelFocusOrLaunchChecksOneSessionAtATimeAndStopsOnFirstMatch() async throws {
        let stores = try makeStores()
        let project = Project(name: "Demo", path: "/tmp/Demo")
        let olderSession = TrackedSession(
            id: "session-older",
            project: project,
            openedAt: Date(timeIntervalSince1970: 100)
        )
        let latestSession = TrackedSession(
            id: "session-latest",
            project: project,
            openedAt: Date(timeIntervalSince1970: 300)
        )
        stores.sessionStore.record(olderSession)
        stores.sessionStore.record(latestSession)
        let focusedRequests = FocusRequestRecorder()
        let runningSession = RunningTerminalSession(
            sessionID: latestSession.id,
            marker: latestSession.marker,
            terminalApp: .appleTerminal,
            terminalWindowID: 42,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: latestSession.terminalTitle
        )
        let viewModel = MenuBarViewModel(
            settingsStore: stores.settingsStore,
            sessionStore: stores.sessionStore,
            focusTrackedSessions: { sessions in
                await focusedRequests.append(sessions.map(\.id))
                if sessions.first?.id == latestSession.id {
                    return [runningSession]
                }

                return []
            },
            launchOpenCodeInTerminal: { _, _, _, _ in
                XCTFail("Should not launch a new session when focusing an existing session succeeds.")
                return OpenCodeLaunchResult(
                    sessionID: "unexpected",
                    terminalWindowID: nil,
                    terminalSessionID: nil,
                    terminalTabTTY: nil,
                    terminalCustomTitle: nil,
                    launchedAt: Date(timeIntervalSince1970: 0)
                )
            }
        )

        await viewModel.focusOrLaunch(project: project).value
        let requestSnapshot = await focusedRequests.snapshot()

        XCTAssertEqual(requestSnapshot, [[latestSession.id]])
        XCTAssertEqual(
            viewModel.status,
            .info(MenuBarRowActionPolicy.showingExistingMessage(projectName: project.name))
        )
    }

    @MainActor
    func testMenuBarViewModelFocusOrLaunchFallsBackWhenLatestSessionIsStale() async throws {
        let stores = try makeStores()
        let project = Project(name: "Demo", path: "/tmp/Demo")
        let olderSession = TrackedSession(
            id: "session-older",
            project: project,
            openedAt: Date(timeIntervalSince1970: 100)
        )
        let latestSession = TrackedSession(
            id: "session-latest",
            project: project,
            openedAt: Date(timeIntervalSince1970: 300)
        )
        stores.sessionStore.record(olderSession)
        stores.sessionStore.record(latestSession)
        let focusedRequests = FocusRequestRecorder()
        let fallbackRunningSession = RunningTerminalSession(
            sessionID: olderSession.id,
            marker: olderSession.marker,
            terminalApp: .appleTerminal,
            terminalWindowID: 7,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys007",
            terminalCustomTitle: olderSession.terminalTitle
        )
        let viewModel = MenuBarViewModel(
            settingsStore: stores.settingsStore,
            sessionStore: stores.sessionStore,
            focusTrackedSessions: { sessions in
                await focusedRequests.append(sessions.map(\.id))
                if sessions.first?.id == olderSession.id {
                    return [fallbackRunningSession]
                }

                return []
            },
            launchOpenCodeInTerminal: { _, _, _, _ in
                XCTFail("Should not launch a new session when fallback focus finds an older running session.")
                return OpenCodeLaunchResult(
                    sessionID: "unexpected",
                    terminalWindowID: nil,
                    terminalSessionID: nil,
                    terminalTabTTY: nil,
                    terminalCustomTitle: nil,
                    launchedAt: Date(timeIntervalSince1970: 0)
                )
            }
        )

        await viewModel.focusOrLaunch(project: project).value
        let requestSnapshot = await focusedRequests.snapshot()

        XCTAssertEqual(requestSnapshot, [[latestSession.id], [olderSession.id]])
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
