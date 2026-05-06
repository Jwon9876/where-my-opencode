import Foundation
import XCTest
@testable import Where_My_OpenCode

final class ITermDriverTests: XCTestCase {
    func testITermDriverReturnsRunningSessionsFromInventoryPayload() throws {
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
        let controller = ITermDriver { _ in
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

    func testITermDriverMatchesRunningSessionByRecordedTerminalMetadata() throws {
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
        let controller = ITermDriver { source in
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

    func testITermDriverDoesNotMatchBlankMetadataToBlankSessionID() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2
        )
        let controller = ITermDriver { _ in
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

    func testITermDriverFocusScriptMatchesRecordedMetadata() throws {
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
        let controller = ITermDriver { source in
            XCTAssertTrue(source.contains("terminalSessionID is expectedSessionID"))
            XCTAssertTrue(source.contains("\"iterm-session-123\""))
            XCTAssertTrue(source.contains("\"42\""))
            XCTAssertTrue(source.contains("\"/dev/ttys042\""))
            XCTAssertTrue(source.contains("select terminalSession"))
            XCTAssertTrue(source.contains("select terminalTab"))
            XCTAssertTrue(source.contains("select terminalWindow"))
            XCTAssertTrue(source.contains("my raiseWindowMatching(\"iTerm2\", markerText)"))
            XCTAssertTrue(source.contains("perform action \"AXRaise\" of axWindow"))
            XCTAssertTrue(source.contains("if windowTitle contains identifier"))
            XCTAssertFalse(source.contains("perform action \"AXRaise\" of window 1"))
            XCTAssertFalse(source.contains("raiseSelectedWindow"))
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

    func testITermDriverFocusesMultipleRunningSessions() throws {
        let firstSession = RunningTerminalSession(
            sessionID: "first-session",
            marker: "WhereMyOpenCode:first-session",
            terminalApp: .iTerm2,
            terminalWindowID: 51,
            terminalSessionID: "iterm-first",
            terminalTabTTY: "/dev/ttys051",
            terminalCustomTitle: "OpenCode"
        )
        let secondSession = RunningTerminalSession(
            sessionID: "second-session",
            marker: "WhereMyOpenCode:second-session",
            terminalApp: .iTerm2,
            terminalWindowID: 52,
            terminalSessionID: "iterm-second",
            terminalTabTTY: "/dev/ttys052",
            terminalCustomTitle: "OpenCode"
        )
        let controller = ITermDriver { source in
            XCTAssertTrue(source.contains("set payloadParts to {}"))
            XCTAssertTrue(source.contains("set end of payloadParts"))
            XCTAssertTrue(source.contains("set candidateMatched to true"))
            XCTAssertTrue(source.contains("select terminalSession"))
            XCTAssertTrue(source.contains("select terminalWindow"))
            XCTAssertTrue(source.contains("my raiseWindowMatching(\"iTerm2\", markerText)"))
            XCTAssertTrue(source.contains("if windowTitle contains identifier"))
            XCTAssertTrue(source.contains("perform action \"AXRaise\" of axWindow"))
            XCTAssertFalse(source.contains("perform action \"AXRaise\" of window 1"))
            XCTAssertFalse(source.contains("raiseSelectedWindow"))
            XCTAssertFalse(source.contains("activate"))

            return """
            found=true
            ---
            marker=\(firstSession.marker)
            terminalWindowID=51
            terminalSessionID=iterm-first
            terminalTabTTY=/dev/ttys051
            terminalCustomTitle=OpenCode
            ---
            marker=\(secondSession.marker)
            terminalWindowID=52
            terminalSessionID=iterm-second
            terminalTabTTY=/dev/ttys052
            terminalCustomTitle=OpenCode
            """
        }

        let result = try controller.focusRunningSessions([firstSession, secondSession])

        XCTAssertEqual(result.map(\.sessionID), ["first-session", "second-session"])
        XCTAssertEqual(result.map(\.terminalSessionID), ["iterm-first", "iterm-second"])
    }

    func testITermDriverReturnsEmptyRunningSessionsWhenITermDoesNotMatch() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2
        )
        let controller = ITermDriver { _ in
            TerminalScriptFixtures.notFound
        }

        let result = try controller.runningSessions(from: [session])

        XCTAssertEqual(result, [])
        XCTAssertEqual(
            controller.runningTerminalSessions(payload: TerminalScriptFixtures.notFound, sessions: [session]),
            []
        )
    }

    func testITermDriverDoesNotInventoryWithoutITermSessions() throws {
        var didRunScript = false
        let controller = ITermDriver { _ in
            didRunScript = true
            return TerminalScriptFixtures.notFound
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

    func testITermDriverReturnsNilWithoutSessions() throws {
        var didRunScript = false
        let controller = ITermDriver { _ in
            didRunScript = true
            return TerminalScriptFixtures.notFound
        }

        let result = try controller.focusFirstRunningSession(from: [])

        XCTAssertNil(result)
        XCTAssertFalse(didRunScript)
    }

    func testITermDriverInventoryScriptScansSessionsOnce() {
        let controller = ITermDriver()

        let script = controller.inventoryScript()

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

    func testITermFocusScriptRaisesPerCandidateMarkerOnly() {
        let firstSession = RunningTerminalSession(
            sessionID: "first-session",
            marker: "WhereMyOpenCode:first-session",
            terminalApp: .iTerm2,
            terminalWindowID: 21,
            terminalSessionID: "iterm-first",
            terminalTabTTY: "/dev/ttys021",
            terminalCustomTitle: "OpenCode"
        )
        let secondSession = RunningTerminalSession(
            sessionID: "second-session",
            marker: "WhereMyOpenCode:second-session",
            terminalApp: .iTerm2,
            terminalWindowID: 22,
            terminalSessionID: "iterm-second",
            terminalTabTTY: "/dev/ttys022",
            terminalCustomTitle: "OpenCode"
        )
        let unrelatedSession = RunningTerminalSession(
            sessionID: "unrelated-session",
            marker: "WhereMyOpenCode:unrelated-session",
            terminalApp: .iTerm2,
            terminalWindowID: 23,
            terminalSessionID: "iterm-unrelated",
            terminalTabTTY: "/dev/ttys023",
            terminalCustomTitle: "OpenCode"
        )
        let controller = ITermDriver()
        let script = controller.focusScript(
            markers: [firstSession.marker, secondSession.marker],
            windowIDs: [
                firstSession.terminalWindowID.map(String.init) ?? "",
                secondSession.terminalWindowID.map(String.init) ?? ""
            ],
            sessionIDs: [
                firstSession.terminalSessionID ?? "",
                secondSession.terminalSessionID ?? ""
            ],
            ttys: [
                firstSession.terminalTabTTY ?? "",
                secondSession.terminalTabTTY ?? ""
            ]
        )

        XCTAssertTrue(script.contains(firstSession.marker))
        XCTAssertTrue(script.contains(secondSession.marker))
        XCTAssertFalse(script.contains(unrelatedSession.marker))
        XCTAssertTrue(script.contains(firstSession.terminalSessionID ?? ""))
        XCTAssertTrue(script.contains(secondSession.terminalSessionID ?? ""))
        XCTAssertFalse(script.contains(unrelatedSession.terminalSessionID ?? ""))

        XCTAssertEqual(occurrences(of: "my raiseWindowMatching(\"iTerm2\", markerText)", in: script), 1)
        XCTAssertEqual(occurrences(of: "perform action \"AXRaise\" of axWindow", in: script), 1)
        XCTAssertFalse(script.contains("perform action \"AXRaise\" of window 1"))
        XCTAssertFalse(script.contains("raiseSelectedWindow"))
        XCTAssertFalse(script.contains("activate"))
    }
}
