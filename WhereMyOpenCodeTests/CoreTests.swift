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
            terminalTabTTY: "/dev/ttys123",
            terminalCustomTitle: "WhereMyOpenCode:session-123 Demo",
            launchedAt: Date(timeIntervalSince1970: 400)
        )

        let updatedSession = session.recordingLaunch(launchResult, terminalApp: .appleTerminal)

        XCTAssertEqual(updatedSession.id, session.id)
        XCTAssertEqual(updatedSession.projectPath, session.projectPath)
        XCTAssertEqual(updatedSession.terminalApp, .appleTerminal)
        XCTAssertEqual(updatedSession.terminalWindowID, 42)
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
        XCTAssertNil(decodedSession.terminalTabTTY)
        XCTAssertNil(decodedSession.terminalCustomTitle)
        XCTAssertNil(decodedSession.launchedAt)
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

    func testOpenCodeLauncherBuildsEscapedCommandAndTerminalTitleScript() {
        let launcher = OpenCodeLauncher()
        let command = launcher.terminalCommand(
            projectPath: "/tmp/John's App",
            opencodePath: "/usr/local/bin/open code"
        )
        let script = launcher.appleTerminalScript(
            command: "echo \"hello\"",
            terminalTitle: "WhereMyOpenCode:abc \"Demo\""
        )

        XCTAssertEqual(command, "cd '/tmp/John'\\''s App' && '/usr/local/bin/open code'")
        XCTAssertTrue(script.contains("repeat 12 times"))
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
        XCTAssertTrue(script.contains("delay 0.25"))
        XCTAssertTrue(script.contains("WhereMyOpenCode:abc \\\"Demo\\\""))
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
        XCTAssertEqual(result.terminalTabTTY, "/dev/ttys123")
        XCTAssertEqual(result.terminalCustomTitle, "WhereMyOpenCode:session-123 Demo")
        XCTAssertEqual(result.launchedAt, launchedAt)
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
