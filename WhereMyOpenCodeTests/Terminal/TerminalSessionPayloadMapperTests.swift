import Foundation
import XCTest
@testable import Where_My_OpenCode

final class TerminalSessionPayloadMapperTests: XCTestCase {
    func testReturnsEmptySessionsForNotFoundPayload() {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            terminalApp: .appleTerminal
        )

        let result = TerminalSessionPayloadMapper.runningSessions(
            payload: TerminalScriptFixtures.notFound,
            sessions: [session],
            terminalApp: .appleTerminal
        )

        XCTAssertEqual(result, [])
    }

    func testMapsAppleTerminalMultiRecordPayloadInCandidateOrder() {
        let olderSession = TrackedSession(
            id: "older-session",
            projectName: "Older",
            projectPath: "/tmp/Older",
            openedAt: Date(timeIntervalSince1970: 100),
            terminalApp: .appleTerminal
        )
        let latestSession = TrackedSession(
            id: "latest-session",
            projectName: "Latest",
            projectPath: "/tmp/Latest",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        let payload = """
        found=true
        ---
        marker=\(olderSession.marker)
        terminalWindowID=7
        terminalSessionID=ignored-apple-session
        terminalTabTTY=/dev/ttys007
        terminalCustomTitle=\(olderSession.terminalTitle)
        ---
        marker=\(latestSession.marker)
        terminalWindowID=9
        terminalSessionID=ignored-latest-session
        terminalTabTTY=/dev/ttys009
        terminalCustomTitle=\(latestSession.terminalTitle)
        """

        let result = TerminalSessionPayloadMapper.runningSessions(
            payload: payload,
            sessions: [olderSession, latestSession],
            terminalApp: .appleTerminal
        )

        XCTAssertEqual(result.map(\.sessionID), ["latest-session", "older-session"])
        XCTAssertEqual(result.map(\.terminalApp), [.appleTerminal, .appleTerminal])
        XCTAssertEqual(result.map(\.terminalWindowID), [9, 7])
        XCTAssertEqual(result.map(\.terminalTabTTY), ["/dev/ttys009", "/dev/ttys007"])
        XCTAssertEqual(result.compactMap(\.terminalSessionID), [])
    }

    func testMapsITermMetadataForTrackedAndRunningSessions() {
        let trackedSession = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2,
            terminalSessionID: "iterm-session-123"
        )
        let runningSession = RunningTerminalSession(
            sessionID: trackedSession.id,
            marker: trackedSession.marker,
            terminalApp: .iTerm2,
            terminalWindowID: 41,
            terminalSessionID: "iterm-session-123",
            terminalTabTTY: "/dev/ttys041",
            terminalCustomTitle: trackedSession.terminalTitle
        )
        let payload = """
        found=true
        ---
        marker=\(trackedSession.marker)
        terminalWindowID=42
        terminalSessionID=iterm-session-123
        terminalTabTTY=/dev/ttys042
        terminalCustomTitle=OpenCode
        """

        let trackedResult = TerminalSessionPayloadMapper.runningSessions(
            payload: payload,
            sessions: [trackedSession],
            terminalApp: .iTerm2
        )
        let runningResult = TerminalSessionPayloadMapper.runningSessions(
            payload: payload,
            sessions: [runningSession],
            terminalApp: .iTerm2
        )

        XCTAssertEqual(trackedResult, runningResult)
        XCTAssertEqual(trackedResult.first?.sessionID, "session-123")
        XCTAssertEqual(trackedResult.first?.terminalWindowID, 42)
        XCTAssertEqual(trackedResult.first?.terminalSessionID, "iterm-session-123")
        XCTAssertEqual(trackedResult.first?.terminalTabTTY, "/dev/ttys042")
        XCTAssertEqual(trackedResult.first?.terminalCustomTitle, "OpenCode")
    }
}
