import Foundation
import XCTest
@testable import Where_My_OpenCode

final class AppleTerminalDriverTests: XCTestCase {
    func testAppleScriptSupportEscapesStringLiterals() {
        XCTAssertEqual(
            AppleScriptSupport.stringLiteral("say \\ \"hello\""),
            "\"say \\\\ \\\"hello\\\"\""
        )
    }

    func testAppleTerminalDriverSearchesMarkersByMostRecentSession() throws {
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
        let controller = AppleTerminalDriver { source in
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

    func testAppleTerminalDriverReturnsRunningSessionsFromInventoryPayload() throws {
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
        let controller = AppleTerminalDriver { _ in
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

    func testAppleTerminalDriverMatchesRunningSessionByRecordedTerminalMetadata() throws {
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
        let controller = AppleTerminalDriver { source in
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

    func testAppleTerminalDriverFocusScriptMatchesRecordedTerminalMetadata() throws {
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
        let controller = AppleTerminalDriver { source in
            XCTAssertTrue(source.contains("terminalWindowID is expectedWindowID and terminalTTY is expectedTTY"))
            XCTAssertTrue(source.contains("\"42\""))
            XCTAssertTrue(source.contains("\"/dev/ttys042\""))
            XCTAssertTrue(source.contains("my raiseWindowMatching(\"Terminal\", markerText)"))
            XCTAssertTrue(source.contains("perform action \"AXRaise\" of axWindow"))
            XCTAssertTrue(source.contains("if windowTitle contains identifier"))
            XCTAssertFalse(source.contains("perform action \"AXRaise\" of window 1"))
            XCTAssertFalse(source.contains("raiseSelectedWindow"))
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

    func testAppleTerminalDriverFocusesMultipleRunningSessions() throws {
        let firstSession = RunningTerminalSession(
            sessionID: "first-session",
            marker: "WhereMyOpenCode:first-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 41,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys041",
            terminalCustomTitle: "WhereMyOpenCode:first-session App"
        )
        let secondSession = RunningTerminalSession(
            sessionID: "second-session",
            marker: "WhereMyOpenCode:second-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 42,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys042",
            terminalCustomTitle: "WhereMyOpenCode:second-session App"
        )
        let controller = AppleTerminalDriver { source in
            XCTAssertTrue(source.contains("set payloadParts to {}"))
            XCTAssertTrue(source.contains("set end of payloadParts"))
            XCTAssertTrue(source.contains("set candidateMatched to true"))
            XCTAssertTrue(source.contains("set selected tab of terminalWindow to terminalTab"))
            XCTAssertTrue(source.contains("my raiseWindowMatching(\"Terminal\", markerText)"))
            XCTAssertTrue(source.contains("if windowTitle contains identifier"))
            XCTAssertFalse(source.contains("perform action \"AXRaise\" of window 1"))
            XCTAssertFalse(source.contains("raiseSelectedWindow"))
            XCTAssertFalse(source.contains("activate"))

            return """
            found=true
            ---
            marker=\(firstSession.marker)
            terminalWindowID=41
            terminalTabTTY=/dev/ttys041
            terminalCustomTitle=OpenCode
            ---
            marker=\(secondSession.marker)
            terminalWindowID=42
            terminalTabTTY=/dev/ttys042
            terminalCustomTitle=OpenCode
            """
        }

        let result = try controller.focusRunningSessions([firstSession, secondSession])

        XCTAssertEqual(result.map(\.sessionID), ["first-session", "second-session"])
        XCTAssertEqual(result.map(\.terminalWindowID), [41, 42])
    }

    func testAppleTerminalDriverReturnsEmptyRunningSessionsWhenTerminalDoesNotMatch() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        let controller = AppleTerminalDriver { _ in
            TerminalScriptFixtures.notFound
        }

        let result = try controller.runningSessions(from: [session])

        XCTAssertEqual(result, [])
        XCTAssertEqual(
            controller.runningTerminalSessions(payload: TerminalScriptFixtures.notFound, sessions: [session]),
            []
        )
    }

    func testAppleTerminalDriverDoesNotInventoryWithoutSessions() throws {
        var didRunScript = false
        let controller = AppleTerminalDriver { _ in
            didRunScript = true
            return TerminalScriptFixtures.notFound
        }

        let result = try controller.runningSessions(from: [])

        XCTAssertEqual(result, [])
        XCTAssertFalse(didRunScript)
    }

    func testAppleTerminalDriverInventoryScriptScansTerminalTabsOnce() {
        let marker = "WhereMyOpenCode:session \\ \"quoted\""
        let controller = AppleTerminalDriver()

        let script = controller.inventoryScript()

        XCTAssertTrue(script.contains("repeat with terminalWindow in windows"))
        XCTAssertTrue(script.contains("repeat with terminalTab in tabs of terminalWindow"))
        XCTAssertTrue(script.contains("terminalWindowID="))
        XCTAssertTrue(script.contains("terminalTabTTY="))
        XCTAssertTrue(script.contains("terminalCustomTitle="))
        XCTAssertFalse(script.contains("repeat with candidateIndex from 1 to count of markersToFind"))
        XCTAssertFalse(script.contains(AppleScriptSupport.stringLiteral(marker)))
    }

    func testAppleTerminalDriverReturnsNilWithoutSessions() throws {
        var didRunScript = false
        let controller = AppleTerminalDriver { _ in
            didRunScript = true
            return TerminalScriptFixtures.notFound
        }

        let result = try controller.focusFirstRunningSession(from: [])

        XCTAssertNil(result)
        XCTAssertFalse(didRunScript)
    }

    func testAppleTerminalDriverReturnsNilWhenTerminalDoesNotMatch() throws {
        let session = TrackedSession(
            id: "session-123",
            projectName: "Demo",
            projectPath: "/tmp/Demo",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        let controller = AppleTerminalDriver { _ in
            TerminalScriptFixtures.notFound
        }

        let result = try controller.focusFirstRunningSession(from: [session])

        XCTAssertNil(result)
        XCTAssertNil(controller.runningTerminalSessions(payload: TerminalScriptFixtures.notFound, sessions: [session]).first)
        XCTAssertNil(
            controller.runningTerminalSessions(
                payload: """
                found=true
                marker=WhereMyOpenCode:unknown
                """,
                sessions: [session]
            ).first
        )
    }

    func testAppleTerminalFocusScriptRaisesPerCandidateMarkerOnly() {
        let firstSession = RunningTerminalSession(
            sessionID: "first-session",
            marker: "WhereMyOpenCode:first-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 11,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys011",
            terminalCustomTitle: "OpenCode"
        )
        let secondSession = RunningTerminalSession(
            sessionID: "second-session",
            marker: "WhereMyOpenCode:second-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 12,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys012",
            terminalCustomTitle: "OpenCode"
        )
        let unrelatedSession = RunningTerminalSession(
            sessionID: "unrelated-session",
            marker: "WhereMyOpenCode:unrelated-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 13,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys013",
            terminalCustomTitle: "OpenCode"
        )
        let controller = AppleTerminalDriver()
        let script = controller.focusScript(
            markers: [firstSession.marker, secondSession.marker],
            windowIDs: [
                firstSession.terminalWindowID.map(String.init) ?? "",
                secondSession.terminalWindowID.map(String.init) ?? ""
            ],
            ttys: [
                firstSession.terminalTabTTY ?? "",
                secondSession.terminalTabTTY ?? ""
            ]
        )

        XCTAssertTrue(script.contains(firstSession.marker))
        XCTAssertTrue(script.contains(secondSession.marker))
        XCTAssertFalse(script.contains(unrelatedSession.marker))

        XCTAssertEqual(occurrences(of: "my raiseWindowMatching(\"Terminal\", markerText)", in: script), 1)
        XCTAssertEqual(occurrences(of: "perform action \"AXRaise\" of axWindow", in: script), 1)
        XCTAssertFalse(script.contains("perform action \"AXRaise\" of window 1"))
        XCTAssertFalse(script.contains("raiseSelectedWindow"))
        XCTAssertFalse(script.contains("activate"))
    }
}
