import Foundation
import XCTest
@testable import Where_My_OpenCode

final class TrackedSessionTests: TemporaryFileTestCase {
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

}
