import Foundation
import XCTest
@testable import Where_My_OpenCode

final class CoreTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }

        try super.tearDownWithError()
    }

    func testProjectScannerFindsMarkedDirectChildrenAndSkipsExcludedFolders() throws {
        let rootURL = try makeTemporaryDirectory()
        let olderProjectURL = rootURL.appendingPathComponent("OlderApp", isDirectory: true)
        let recentProjectURL = rootURL.appendingPathComponent("RecentApp", isDirectory: true)
        let excludedProjectURL = rootURL.appendingPathComponent("node_modules", isDirectory: true)

        try FileManager.default.createDirectory(at: olderProjectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: recentProjectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: excludedProjectURL, withIntermediateDirectories: true)

        try writeEmptyFile(at: olderProjectURL.appendingPathComponent("package.json"))
        try writeEmptyFile(at: recentProjectURL.appendingPathComponent("Cargo.toml"))
        try writeEmptyFile(at: excludedProjectURL.appendingPathComponent("package.json"))

        try setModificationDate(Date(timeIntervalSince1970: 100), for: olderProjectURL)
        try setModificationDate(Date(timeIntervalSince1970: 200), for: recentProjectURL)

        let projects = try ProjectScanner().scan(rootFolderURL: rootURL)

        XCTAssertEqual(projects.map(\.name), ["RecentApp", "OlderApp"])
        XCTAssertFalse(projects.map(\.name).contains("node_modules"))
    }

    func testTrackedSessionNormalizesPathAndBuildsTerminalMarker() throws {
        let rootURL = try makeTemporaryDirectory()
        let rawPath = rootURL
            .appendingPathComponent("Workspace")
            .appendingPathComponent("Nested")
            .appendingPathComponent("..")
            .appendingPathComponent("App")
            .path

        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo\nProject",
            projectPath: rawPath,
            openedAt: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(session.projectPath, (rawPath as NSString).standardizingPath)
        XCTAssertEqual(session.marker, "WhereMyOpenCode:session-123")
        XCTAssertEqual(session.terminalTitle, "WhereMyOpenCode:session-123 Demo Project")
        XCTAssertNil(session.terminalApp)
        XCTAssertNil(session.terminalWindowID)
        XCTAssertNil(session.terminalSessionID)
        XCTAssertNil(session.terminalTabTTY)
        XCTAssertNil(session.terminalCustomTitle)
        XCTAssertNil(session.launchedAt)
    }

    func testTrackedSessionRecordsTerminalMetadataFromLaunchResult() {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300)
        )
        let launchResult = OpenCodeLaunchResult(
            sessionID: "session-123",
            terminalWindowID: 42,
            terminalSessionID: "iterm-session-123",
            terminalTabTTY: "/dev/ttys123",
            terminalCustomTitle: "WhereMyOpenCode:session-123 Demo",
            launchedAt: Date(timeIntervalSince1970: 400)
        )

        let updatedSession = session.recordingLaunch(launchResult, terminalApp: .iTerm2)

        XCTAssertEqual(updatedSession.id, session.id)
        XCTAssertEqual(updatedSession.projectPath, session.projectPath)
        XCTAssertEqual(updatedSession.terminalApp, .iTerm2)
        XCTAssertEqual(updatedSession.terminalWindowID, 42)
        XCTAssertEqual(updatedSession.terminalSessionID, "iterm-session-123")
        XCTAssertEqual(updatedSession.terminalTabTTY, "/dev/ttys123")
        XCTAssertEqual(updatedSession.terminalCustomTitle, "WhereMyOpenCode:session-123 Demo")
        XCTAssertEqual(updatedSession.launchedAt, Date(timeIntervalSince1970: 400))
    }

    func testTrackedSessionDecodesLegacyJSONWithoutTerminalMetadata() throws {
        let legacyJSON = """
        {
          "id": "legacy-session",
          "projectName": "Legacy",
          "projectPath": "/tmp/Legacy",
          "openedAt": 300,
          "marker": "WhereMyOpenCode:legacy-session",
          "terminalTitle": "WhereMyOpenCode:legacy-session Legacy"
        }
        """

        let decodedSession = try JSONDecoder().decode(TrackedSession.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(decodedSession.id, "legacy-session")
        XCTAssertNil(decodedSession.terminalApp)
        XCTAssertNil(decodedSession.terminalWindowID)
        XCTAssertNil(decodedSession.terminalSessionID)
        XCTAssertNil(decodedSession.terminalTabTTY)
        XCTAssertNil(decodedSession.terminalCustomTitle)
        XCTAssertNil(decodedSession.launchedAt)
    }

    func testTerminalAppDisplayNamesIncludeITerm2() {
        XCTAssertEqual(TerminalApp.appleTerminal.displayName, "Apple Terminal")
        XCTAssertEqual(TerminalApp.iTerm2.displayName, "iTerm2")
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

    func testSessionStorePersistsHistoryAndReturnsLatestSessionPerProject() throws {
        let rootURL = try makeTemporaryDirectory()
        let sessionsURL = rootURL.appendingPathComponent("sessions.json")
        let appPath = rootURL.appendingPathComponent("App").path
        let toolPath = rootURL.appendingPathComponent("Tool").path
        let equivalentAppPath = rootURL
            .appendingPathComponent("Nested")
            .appendingPathComponent("..")
            .appendingPathComponent("App")
            .path

        let store = SessionStore(sessionsURL: sessionsURL, maxStoredSessions: 10)
        let oldAppSession = TrackedSession(
            id: "old-app",
            projectName: "App",
            projectPath: appPath,
            openedAt: Date(timeIntervalSince1970: 100)
        )
        let toolSession = TrackedSession(
            id: "tool",
            projectName: "Tool",
            projectPath: toolPath,
            openedAt: Date(timeIntervalSince1970: 200)
        )
        let latestAppSession = TrackedSession(
            id: "latest-app",
            projectName: "App",
            projectPath: equivalentAppPath,
            openedAt: Date(timeIntervalSince1970: 300)
        )

        store.record(oldAppSession)
        store.record(toolSession)
        store.record(latestAppSession)

        XCTAssertEqual(store.recentSessions(limit: 10).map(\.id), ["latest-app", "tool"])

        let reloadedStore = SessionStore(sessionsURL: sessionsURL, maxStoredSessions: 10)
        XCTAssertEqual(reloadedStore.sessions.map(\.id), ["latest-app", "tool", "old-app"])
        XCTAssertEqual(reloadedStore.sessions(forProjectPath: appPath).map(\.id), ["latest-app", "old-app"])
    }

    func testAppleScriptSupportEscapesStringLiterals() {
        XCTAssertEqual(
            AppleScriptSupport.stringLiteral("say \\ \"hello\""),
            "\"say \\\\ \\\"hello\\\"\""
        )
    }

    func testAppleTerminalSessionControllerSearchesMarkersByMostRecentSession() throws {
        let oldSession = TrackedSession(
            id: "old-session",
            projectName: "App",
            projectPath: "/tmp/App",
            openedAt: Date(timeIntervalSince1970: 100),
            terminalApp: .appleTerminal
        )
        let latestSession = TrackedSession(
            id: "latest-session",
            projectName: "App",
            projectPath: "/tmp/App",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        var capturedScript = ""
        let controller = AppleTerminalSessionController { source in
            capturedScript = source

            return """
            found=true
            marker=\(latestSession.marker)
            terminalWindowID=7
            terminalTabTTY=/dev/ttys007
            terminalCustomTitle=\(latestSession.terminalTitle)
            """
        }

        let result = try controller.focusFirstRunningSession(from: [oldSession, latestSession])

        XCTAssertEqual(result?.sessionID, "latest-session")
        XCTAssertEqual(result?.marker, latestSession.marker)
        XCTAssertEqual(result?.terminalApp, .appleTerminal)
        XCTAssertEqual(result?.terminalWindowID, 7)
        XCTAssertNil(result?.terminalSessionID)
        XCTAssertEqual(result?.terminalTabTTY, "/dev/ttys007")
        XCTAssertEqual(result?.terminalCustomTitle, latestSession.terminalTitle)
        XCTAssertTrue(capturedScript.contains("if application \"Terminal\" is not running"))
        XCTAssertTrue(capturedScript.contains("set selected tab of terminalWindow to terminalTab"))
        XCTAssertTrue(capturedScript.contains("terminalCustomTitle begins with markerText"))

        let latestMarkerRange = try XCTUnwrap(capturedScript.range(of: latestSession.marker))
        let oldMarkerRange = try XCTUnwrap(capturedScript.range(of: oldSession.marker))
        XCTAssertTrue(latestMarkerRange.lowerBound < oldMarkerRange.lowerBound)
    }

    func testAppleTerminalSessionControllerReturnsRunningSessionsFromInventoryPayload() throws {
        let oldSession = TrackedSession(
            id: "old-session",
            projectName: "App",
            projectPath: "/tmp/App",
            openedAt: Date(timeIntervalSince1970: 100),
            terminalApp: .appleTerminal
        )
        let latestSession = TrackedSession(
            id: "latest-session",
            projectName: "Tool",
            projectPath: "/tmp/Tool",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        let staleSession = TrackedSession(
            id: "stale-session",
            projectName: "Stale",
            projectPath: "/tmp/Stale",
            openedAt: Date(timeIntervalSince1970: 400),
            terminalApp: .appleTerminal
        )
        let controller = AppleTerminalSessionController { _ in
            """
            found=true
            ---
            marker=\(oldSession.marker)
            terminalWindowID=7
            terminalTabTTY=/dev/ttys007
            terminalCustomTitle=\(oldSession.terminalTitle)
            ---
            marker=WhereMyOpenCode:unknown
            terminalWindowID=8
            terminalTabTTY=/dev/ttys008
            terminalCustomTitle=WhereMyOpenCode:unknown Unknown
            ---
            marker=\(latestSession.marker)
            terminalWindowID=9
            terminalTabTTY=/dev/ttys009
            terminalCustomTitle=\(latestSession.terminalTitle)
            ---
            marker=\(oldSession.marker)
            terminalWindowID=99
            terminalTabTTY=/dev/ttys099
            terminalCustomTitle=\(oldSession.marker) Duplicate
            """
        }

        let result = try controller.runningSessions(from: [oldSession, staleSession, latestSession])

        XCTAssertEqual(result.map(\.sessionID), ["latest-session", "old-session"])
        XCTAssertEqual(result.map(\.marker), [latestSession.marker, oldSession.marker])
        XCTAssertEqual(result.map(\.terminalApp), [.appleTerminal, .appleTerminal])
        XCTAssertEqual(result.first?.terminalWindowID, 9)
        XCTAssertNil(result.first?.terminalSessionID)
        XCTAssertEqual(result.first?.terminalTabTTY, "/dev/ttys009")
        XCTAssertEqual(result.first?.terminalCustomTitle, latestSession.terminalTitle)
        XCTAssertEqual(result.last?.terminalWindowID, 7)
        XCTAssertEqual(result.last?.terminalTabTTY, "/dev/ttys007")
    }

    func testAppleTerminalSessionControllerMatchesRunningSessionByRecordedTerminalMetadata() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal,
            terminalWindowID: 42,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: "WhereMyOpenCode:session-123 Demo",
            launchedAt: Date(timeIntervalSince1970: 400)
        )
        let staleSessionWithReusedTTY = TrackedSession(
            id: "stale-session",
            projectName: "Stale",
            projectPath: "/tmp/Stale",
            openedAt: Date(timeIntervalSince1970: 200),
            terminalApp: .appleTerminal,
            terminalWindowID: 7,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: "WhereMyOpenCode:stale-session Stale",
            launchedAt: Date(timeIntervalSince1970: 250)
        )
        let controller = AppleTerminalSessionController { source in
            XCTAssertFalse(source.contains("\"42\""))
            XCTAssertFalse(source.contains("\"/dev/ttys042\""))
            XCTAssertFalse(source.contains("repeat with candidateIndex from 1 to count of markersToFind"))

            return """
            found=true
            ---
            terminalWindowID=42
            terminalTabTTY=/dev/ttys042
            terminalCustomTitle=OpenCode
            """
        }

        let result = try controller.runningSessions(from: [staleSessionWithReusedTTY, session])

        XCTAssertEqual(result.map(\.sessionID), ["session-123"])
        XCTAssertEqual(result.first?.terminalCustomTitle, "OpenCode")
    }

    func testAppleTerminalSessionControllerFocusScriptMatchesRecordedTerminalMetadata() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal,
            terminalWindowID: 42,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: "WhereMyOpenCode:session-123 Demo",
            launchedAt: Date(timeIntervalSince1970: 400)
        )
        let controller = AppleTerminalSessionController { source in
            XCTAssertTrue(source.contains("terminalWindowID is expectedWindowID and terminalTTY is expectedTTY"))
            XCTAssertTrue(source.contains("\"42\""))
            XCTAssertTrue(source.contains("\"/dev/ttys042\""))
            XCTAssertTrue(source.contains("my raiseSelectedWindow(\"Terminal\")"))
            XCTAssertTrue(source.contains("perform action \"AXRaise\" of window 1"))
            XCTAssertFalse(source.contains("\n                            activate"))

            return """
            found=true
            marker=\(session.marker)
            terminalWindowID=42
            terminalTabTTY=/dev/ttys042
            terminalCustomTitle=OpenCode
            """
        }

        let result = try controller.focusFirstRunningSession(from: [session])

        XCTAssertEqual(result?.sessionID, "session-123")
        XCTAssertEqual(result?.terminalCustomTitle, "OpenCode")
    }

    func testAppleTerminalSessionControllerReturnsEmptyRunningSessionsWhenTerminalDoesNotMatch() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        let controller = AppleTerminalSessionController { _ in
            "found=false"
        }

        let result = try controller.runningSessions(from: [session])

        XCTAssertEqual(result, [])
        XCTAssertEqual(
            controller.runningTerminalSessions(payload: "found=false", sessions: [session]),
            []
        )
    }

    func testAppleTerminalSessionControllerDoesNotInventoryWithoutSessions() throws {
        var didRunScript = false
        let controller = AppleTerminalSessionController { _ in
            didRunScript = true
            return "found=false"
        }

        let result = try controller.runningSessions(from: [])

        XCTAssertEqual(result, [])
        XCTAssertFalse(didRunScript)
    }

    func testAppleTerminalSessionControllerInventoryScriptScansTerminalTabsOnce() {
        let marker = "WhereMyOpenCode:session \\ \"quoted\""
        let controller = AppleTerminalSessionController()

        let script = controller.appleTerminalInventoryScript(markers: [marker])

        XCTAssertTrue(script.contains("repeat with terminalWindow in windows"))
        XCTAssertTrue(script.contains("repeat with terminalTab in tabs of terminalWindow"))
        XCTAssertTrue(script.contains("terminalWindowID="))
        XCTAssertTrue(script.contains("terminalTabTTY="))
        XCTAssertTrue(script.contains("terminalCustomTitle="))
        XCTAssertFalse(script.contains("repeat with candidateIndex from 1 to count of markersToFind"))
        XCTAssertFalse(script.contains(AppleScriptSupport.stringLiteral(marker)))
    }

    func testAppleTerminalSessionControllerReturnsNilWithoutSessions() throws {
        var didRunScript = false
        let controller = AppleTerminalSessionController { _ in
            didRunScript = true
            return "found=false"
        }

        let result = try controller.focusFirstRunningSession(from: [])

        XCTAssertNil(result)
        XCTAssertFalse(didRunScript)
    }

    func testAppleTerminalSessionControllerReturnsNilWhenTerminalDoesNotMatch() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        let controller = AppleTerminalSessionController { _ in
            "found=false"
        }

        let result = try controller.focusFirstRunningSession(from: [session])

        XCTAssertNil(result)
        XCTAssertNil(controller.runningTerminalSession(payload: "found=false", sessions: [session]))
        XCTAssertNil(
            controller.runningTerminalSession(
                payload: """
                found=true
                marker=WhereMyOpenCode:unknown
                """,
                sessions: [session]
            )
        )
    }

    func testOpenCodeLauncherBuildsEscapedCommandAndTerminalTitleScript() {
        let launcher = OpenCodeLauncher()
        let command = launcher.terminalCommand(
            projectPath: "/tmp/John's App",
            opencodePath: "/usr/local/bin/open code"
        )
        let script = launcher.appleTerminalScript(
            command: "echo \"hello\"",
            terminalTitle: "WhereMyOpenCode:abc \"Demo\"",
            marker: "WhereMyOpenCode:abc"
        )

        XCTAssertEqual(command, "cd '/tmp/John'\\''s App' && '/usr/local/bin/open code'")
        XCTAssertTrue(script.contains("repeat 6 times"))
        XCTAssertTrue(script.contains("set custom title of launchedTab"))
        XCTAssertTrue(script.contains("set title displays custom title of launchedTab to true"))
        XCTAssertTrue(script.contains("set title displays device name of launchedTab to false"))
        XCTAssertTrue(script.contains("set title displays shell path of launchedTab to false"))
        XCTAssertTrue(script.contains("set title displays window size of launchedTab to false"))
        XCTAssertTrue(script.contains("set title displays file name of launchedTab to false"))
        XCTAssertTrue(script.contains("set launchedWindowID to \"\""))
        XCTAssertTrue(script.contains("set launchedTTY to \"\""))
        XCTAssertTrue(script.contains("set launchedCustomTitle to \"\""))
        XCTAssertTrue(script.contains("set launchedTTY to tty of launchedTab"))
        XCTAssertTrue(script.contains("set launchedWindowID to (id of terminalWindow as text)"))
        XCTAssertTrue(script.contains("custom title of terminalTab is launchedCustomTitle"))
        XCTAssertTrue(script.contains("return \"terminalWindowID=\" & launchedWindowID"))
        XCTAssertTrue(script.contains("delay 0.05"))
        XCTAssertFalse(script.contains("delay 0.25"))
        XCTAssertFalse(script.contains("repeat 12 times"))
        XCTAssertTrue(script.contains("my raiseWindowMatching(\"Terminal\", \"WhereMyOpenCode:abc\")"))
        XCTAssertTrue(script.contains("if windowTitle contains identifier"))
        XCTAssertTrue(script.contains("perform action \"AXRaise\" of axWindow"))
        XCTAssertFalse(script.contains("perform action \"AXRaise\" of window 1"))
        XCTAssertFalse(script.contains("raiseSelectedWindow"))
        XCTAssertTrue(script.contains("set selected tab of launchedWindow to launchedTab"))
        XCTAssertFalse(script.contains("activate"))
        XCTAssertTrue(script.contains("WhereMyOpenCode:abc \\\"Demo\\\""))
    }

    func testOpenCodeLauncherBuildsAppleTerminalScriptWithoutExplicitFocus() {
        let launcher = OpenCodeLauncher()
        let script = launcher.appleTerminalScript(
            command: "echo \"hello\"",
            terminalTitle: "WhereMyOpenCode:abc Demo",
            marker: "WhereMyOpenCode:abc",
            focusPolicy: .none
        )

        XCTAssertFalse(script.contains("activate"))
        XCTAssertFalse(script.contains("raiseSelectedWindow"))
        XCTAssertFalse(script.contains("raiseWindowMatching"))
        XCTAssertFalse(script.contains("AXRaise"))
        XCTAssertFalse(script.contains("set selected tab of launchedWindow to launchedTab"))
    }

    func testOpenCodeLauncherBuildsITerm2Script() {
        let launcher = OpenCodeLauncher()
        let script = launcher.iTerm2Script(
            command: "echo \"hello\"",
            terminalTitle: "WhereMyOpenCode:abc Demo",
            marker: "WhereMyOpenCode:abc"
        )

        XCTAssertTrue(script.contains("set iTermWasRunning to application id \"com.googlecode.iterm2\" is running"))
        XCTAssertTrue(script.contains("tell application id \"com.googlecode.iterm2\""))
        XCTAssertTrue(script.contains("set launchedWindow to create window with default profile"))
        XCTAssertTrue(script.contains("launch"))
        XCTAssertTrue(script.contains("repeat 20 times"))
        XCTAssertTrue(script.contains("set launchedTab to current tab of launchedWindow"))
        XCTAssertTrue(script.contains("tell launchedSession to write text"))
        XCTAssertFalse(script.contains("create tab with default profile"))
        XCTAssertFalse(script.contains("create tab with default profile command"))
        XCTAssertFalse(script.contains("create window with default profile command"))
        XCTAssertTrue(script.contains("set name of launchedSession"))
        XCTAssertTrue(script.contains("unique id of launchedSession"))
        XCTAssertTrue(script.contains("tty of launchedSession"))
        XCTAssertTrue(script.contains("select launchedSession"))
        XCTAssertTrue(script.contains("select launchedWindow"))
        XCTAssertTrue(script.contains("my raiseWindowMatching(\"iTerm2\", \"WhereMyOpenCode:abc\")"))
        XCTAssertTrue(script.contains("if windowTitle contains identifier"))
        XCTAssertTrue(script.contains("perform action \"AXRaise\" of axWindow"))
        XCTAssertFalse(script.contains("perform action \"AXRaise\" of window 1"))
        XCTAssertFalse(script.contains("raiseSelectedWindow"))
        XCTAssertTrue(script.contains("return \"terminalWindowID=\" & launchedWindowID"))
        XCTAssertTrue(script.contains("terminalSessionID=\" & launchedSessionID"))
        XCTAssertFalse(script.contains("whereMyOpenCodeMarker"))
        XCTAssertFalse(script.contains("terminalMarker="))
        XCTAssertFalse(script.contains("activate"))
        XCTAssertTrue(script.contains("WhereMyOpenCode:abc Demo"))
    }

    func testOpenCodeLauncherBuildsITerm2ScriptWithoutExplicitFocus() {
        let launcher = OpenCodeLauncher()
        let script = launcher.iTerm2Script(
            command: "echo \"hello\"",
            terminalTitle: "WhereMyOpenCode:abc Demo",
            marker: "WhereMyOpenCode:abc",
            focusPolicy: .none
        )

        XCTAssertFalse(script.contains("activate"))
        XCTAssertFalse(script.contains("raiseSelectedWindow"))
        XCTAssertFalse(script.contains("raiseWindowMatching"))
        XCTAssertFalse(script.contains("AXRaise"))
        XCTAssertFalse(script.contains("select launchedSession"))
        XCTAssertFalse(script.contains("select launchedWindow"))
    }

    func testOpenCodeLauncherParsesTerminalMetadataPayload() {
        let launcher = OpenCodeLauncher()
        let launchedAt = Date(timeIntervalSince1970: 500)
        let result = launcher.appleTerminalLaunchResult(
            sessionID: "session-123",
            payload: """
            terminalWindowID=100
            terminalTabTTY=/dev/ttys123
            terminalCustomTitle=WhereMyOpenCode:session-123 Demo
            """,
            launchedAt: launchedAt
        )

        XCTAssertEqual(result.sessionID, "session-123")
        XCTAssertEqual(result.terminalWindowID, 100)
        XCTAssertNil(result.terminalSessionID)
        XCTAssertEqual(result.terminalTabTTY, "/dev/ttys123")
        XCTAssertEqual(result.terminalCustomTitle, "WhereMyOpenCode:session-123 Demo")
        XCTAssertEqual(result.launchedAt, launchedAt)
    }

    func testOpenCodeLauncherParsesITerm2MetadataPayload() {
        let launcher = OpenCodeLauncher()
        let launchedAt = Date(timeIntervalSince1970: 600)
        let result = launcher.terminalLaunchResult(
            sessionID: "session-123",
            payload: """
            terminalWindowID=100
            terminalSessionID=iterm-session-123
            terminalTabTTY=/dev/ttys123
            terminalCustomTitle=WhereMyOpenCode:session-123 Demo
            """,
            launchedAt: launchedAt
        )

        XCTAssertEqual(result.sessionID, "session-123")
        XCTAssertEqual(result.terminalWindowID, 100)
        XCTAssertEqual(result.terminalSessionID, "iterm-session-123")
        XCTAssertEqual(result.terminalTabTTY, "/dev/ttys123")
        XCTAssertEqual(result.terminalCustomTitle, "WhereMyOpenCode:session-123 Demo")
        XCTAssertEqual(result.launchedAt, launchedAt)
    }

    func testITermSessionControllerReturnsRunningSessionsFromInventoryPayload() throws {
        let oldSession = TrackedSession(
            id: "old-session",
            projectName: "App",
            projectPath: "/tmp/App",
            openedAt: Date(timeIntervalSince1970: 100),
            terminalApp: .iTerm2,
            terminalSessionID: "old-iterm-session"
        )
        let latestSession = TrackedSession(
            id: "latest-session",
            projectName: "Tool",
            projectPath: "/tmp/Tool",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2,
            terminalSessionID: "latest-iterm-session"
        )
        let staleSession = TrackedSession(
            id: "stale-session",
            projectName: "Stale",
            projectPath: "/tmp/Stale",
            openedAt: Date(timeIntervalSince1970: 400),
            terminalApp: .iTerm2,
            terminalSessionID: "stale-iterm-session"
        )
        let appleTerminalSession = TrackedSession(
            id: "apple-session",
            projectName: "Apple",
            projectPath: "/tmp/Apple",
            openedAt: Date(timeIntervalSince1970: 500),
            terminalApp: .appleTerminal
        )
        let controller = ITermSessionController { _ in
            """
            found=true
            ---
            terminalWindowID=7
            terminalSessionID=old-iterm-session
            terminalTabTTY=/dev/ttys007
            terminalCustomTitle=OpenCode
            ---
            terminalWindowID=8
            terminalSessionID=unknown-iterm-session
            terminalTabTTY=/dev/ttys008
            terminalCustomTitle=Unknown
            ---
            terminalWindowID=9
            terminalSessionID=latest-iterm-session
            terminalTabTTY=/dev/ttys009
            terminalCustomTitle=OpenCode
            ---
            terminalWindowID=99
            terminalSessionID=old-iterm-session
            terminalTabTTY=/dev/ttys099
            terminalCustomTitle=Duplicate
            """
        }

        let result = try controller.runningSessions(
            from: [oldSession, staleSession, latestSession, appleTerminalSession]
        )

        XCTAssertEqual(result.map(\.sessionID), ["latest-session", "old-session"])
        XCTAssertEqual(result.map(\.marker), [latestSession.marker, oldSession.marker])
        XCTAssertEqual(result.map(\.terminalApp), [.iTerm2, .iTerm2])
        XCTAssertEqual(result.first?.terminalWindowID, 9)
        XCTAssertEqual(result.first?.terminalSessionID, "latest-iterm-session")
        XCTAssertEqual(result.first?.terminalTabTTY, "/dev/ttys009")
        XCTAssertEqual(result.first?.terminalCustomTitle, "OpenCode")
        XCTAssertEqual(result.last?.terminalWindowID, 7)
        XCTAssertEqual(result.last?.terminalSessionID, "old-iterm-session")
    }

    func testITermSessionControllerMatchesRunningSessionByRecordedTerminalMetadata() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2,
            terminalWindowID: 42,
            terminalSessionID: "iterm-session-123",
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: "WhereMyOpenCode:session-123 Demo",
            launchedAt: Date(timeIntervalSince1970: 400)
        )
        let controller = ITermSessionController { source in
            XCTAssertFalse(source.contains("\"iterm-session-123\""))
            XCTAssertFalse(source.contains("repeat with candidateIndex from 1 to count of markersToFind"))

            return """
            found=true
            ---
            terminalWindowID=42
            terminalSessionID=iterm-session-123
            terminalTabTTY=/dev/ttys042
            terminalCustomTitle=OpenCode
            """
        }

        let result = try controller.runningSessions(from: [session])

        XCTAssertEqual(result.map(\.sessionID), ["session-123"])
        XCTAssertEqual(result.first?.terminalSessionID, "iterm-session-123")
        XCTAssertEqual(result.first?.terminalCustomTitle, "OpenCode")
    }

    func testITermSessionControllerDoesNotMatchBlankMetadataToBlankSessionID() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2
        )
        let controller = ITermSessionController { _ in
            """
            found=true
            ---
            terminalWindowID=
            terminalSessionID=
            terminalTabTTY=
            terminalCustomTitle=OpenCode
            """
        }

        let result = try controller.runningSessions(from: [session])

        XCTAssertEqual(result, [])
    }

    func testITermSessionControllerFocusScriptMatchesRecordedMetadata() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2,
            terminalWindowID: 42,
            terminalSessionID: "iterm-session-123",
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: "WhereMyOpenCode:session-123 Demo",
            launchedAt: Date(timeIntervalSince1970: 400)
        )
        let controller = ITermSessionController { source in
            XCTAssertTrue(source.contains("terminalSessionID is expectedSessionID"))
            XCTAssertTrue(source.contains("\"iterm-session-123\""))
            XCTAssertTrue(source.contains("\"42\""))
            XCTAssertTrue(source.contains("\"/dev/ttys042\""))
            XCTAssertTrue(source.contains("select terminalSession"))
            XCTAssertTrue(source.contains("select terminalTab"))
            XCTAssertTrue(source.contains("select terminalWindow"))
            XCTAssertTrue(source.contains("my raiseSelectedWindow(\"iTerm2\")"))
            XCTAssertTrue(source.contains("perform action \"AXRaise\" of window 1"))
            XCTAssertFalse(source.contains("\n                                activate"))

            return """
            found=true
            marker=\(session.marker)
            terminalWindowID=42
            terminalSessionID=iterm-session-123
            terminalTabTTY=/dev/ttys042
            terminalCustomTitle=OpenCode
            """
        }

        let result = try controller.focusFirstRunningSession(from: [session])

        XCTAssertEqual(result?.sessionID, "session-123")
        XCTAssertEqual(result?.terminalApp, .iTerm2)
        XCTAssertEqual(result?.terminalSessionID, "iterm-session-123")
        XCTAssertEqual(result?.terminalCustomTitle, "OpenCode")
    }

    func testITermSessionControllerReturnsEmptyRunningSessionsWhenITermDoesNotMatch() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2
        )
        let controller = ITermSessionController { _ in
            "found=false"
        }

        let result = try controller.runningSessions(from: [session])

        XCTAssertEqual(result, [])
        XCTAssertEqual(
            controller.runningTerminalSessions(payload: "found=false", sessions: [session]),
            []
        )
    }

    func testITermSessionControllerDoesNotInventoryWithoutITermSessions() throws {
        var didRunScript = false
        let controller = ITermSessionController { _ in
            didRunScript = true
            return "found=false"
        }
        let appleTerminalSession = TrackedSession(
            id: "apple-session",
            projectName: "Apple",
            projectPath: "/tmp/Apple",
            terminalApp: .appleTerminal
        )

        let result = try controller.runningSessions(from: [appleTerminalSession])

        XCTAssertEqual(result, [])
        XCTAssertFalse(didRunScript)
    }

    func testITermSessionControllerReturnsNilWithoutSessions() throws {
        var didRunScript = false
        let controller = ITermSessionController { _ in
            didRunScript = true
            return "found=false"
        }

        let result = try controller.focusFirstRunningSession(from: [])

        XCTAssertNil(result)
        XCTAssertFalse(didRunScript)
    }

    func testITermSessionControllerInventoryScriptScansSessionsOnce() {
        let controller = ITermSessionController()

        let script = controller.iTerm2InventoryScript()

        XCTAssertTrue(script.contains("if application id \"com.googlecode.iterm2\" is not running"))
        XCTAssertTrue(script.contains("repeat with terminalWindow in windows"))
        XCTAssertTrue(script.contains("repeat with terminalTab in tabs of terminalWindow"))
        XCTAssertTrue(script.contains("repeat with terminalSession in sessions of terminalTab"))
        XCTAssertTrue(script.contains("unique id of terminalSession"))
        XCTAssertTrue(script.contains("tty of terminalSession"))
        XCTAssertTrue(script.contains("terminalSessionID="))
        XCTAssertFalse(script.contains("whereMyOpenCodeMarker"))
        XCTAssertFalse(script.contains("terminalMarker="))
        XCTAssertFalse(script.contains("repeat with candidateIndex from 1 to count of markersToFind"))
    }

    func testTerminalSessionControllerCombinesRunningSessionsAcrossTerminalApps() throws {
        let appleSession = TrackedSession(
            id: "apple-session",
            projectName: "Apple",
            projectPath: "/tmp/Apple",
            openedAt: Date(timeIntervalSince1970: 100),
            terminalApp: .appleTerminal
        )
        let iTermSession = TrackedSession(
            id: "iterm-session",
            projectName: "iTerm",
            projectPath: "/tmp/iTerm",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2,
            terminalSessionID: "iterm-session-id"
        )
        var didRunAppleScript = false
        var didRunITermScript = false
        let appleController = AppleTerminalSessionController { _ in
            didRunAppleScript = true

            return """
            found=true
            ---
            marker=\(appleSession.marker)
            terminalWindowID=7
            terminalTabTTY=/dev/ttys007
            terminalCustomTitle=\(appleSession.terminalTitle)
            """
        }
        let iTermController = ITermSessionController { _ in
            didRunITermScript = true

            return """
            found=true
            ---
            terminalWindowID=9
            terminalSessionID=iterm-session-id
            terminalTabTTY=/dev/ttys009
            terminalCustomTitle=OpenCode
            """
        }
        let controller = TerminalSessionController(
            appleTerminalSessionController: appleController,
            iTermSessionController: iTermController
        )

        let result = try controller.runningSessions(from: [appleSession, iTermSession])

        XCTAssertTrue(didRunAppleScript)
        XCTAssertTrue(didRunITermScript)
        XCTAssertEqual(result.map(\.sessionID), ["iterm-session", "apple-session"])
        XCTAssertEqual(result.map(\.terminalApp), [.iTerm2, .appleTerminal])
        XCTAssertEqual(result.first?.terminalSessionID, "iterm-session-id")
        XCTAssertNil(result.last?.terminalSessionID)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhereMyOpenCodeTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }

    private func writeEmptyFile(at url: URL) throws {
        try Data().write(to: url)
    }

    private func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
