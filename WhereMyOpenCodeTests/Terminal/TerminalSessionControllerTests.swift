import Foundation
import XCTest
@testable import Where_My_OpenCode

final class TerminalSessionControllerTests: XCTestCase {
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
        let appleController = AppleTerminalDriver { _ in
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
        let iTermController = ITermDriver { _ in
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
        let controller = TerminalSessionController(drivers: [appleController, iTermController])

        let result = try controller.runningSessions(from: [appleSession, iTermSession])

        XCTAssertTrue(didRunAppleScript)
        XCTAssertTrue(didRunITermScript)
        XCTAssertEqual(result.map(\.sessionID), ["iterm-session", "apple-session"])
        XCTAssertEqual(result.map(\.terminalApp), [.iTerm2, .appleTerminal])
        XCTAssertEqual(result.first?.terminalSessionID, "iterm-session-id")
        XCTAssertNil(result.last?.terminalSessionID)
    }

    func testTerminalSessionControllerFocusesOnlyProjectCandidateRunningSessions() throws {
        let olderAppSession = TrackedSession(
            id: "older-app",
            projectName: "App",
            projectPath: "/tmp/App",
            openedAt: Date(timeIntervalSince1970: 100),
            terminalApp: .appleTerminal
        )
        let latestAppSession = TrackedSession(
            id: "latest-app",
            projectName: "App",
            projectPath: "/tmp/App",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .appleTerminal
        )
        let toolSession = TrackedSession(
            id: "tool",
            projectName: "Tool",
            projectPath: "/tmp/Tool",
            openedAt: Date(timeIntervalSince1970: 400),
            terminalApp: .appleTerminal
        )
        var appleScripts: [String] = []
        let appleController = AppleTerminalDriver { source in
            appleScripts.append(source)

            if source.contains("markersToFind") {
                XCTAssertTrue(source.contains(latestAppSession.marker))
                XCTAssertTrue(source.contains(olderAppSession.marker))
                XCTAssertFalse(source.contains(toolSession.marker))

                return """
                found=true
                ---
                marker=\(latestAppSession.marker)
                terminalWindowID=9
                terminalTabTTY=/dev/ttys009
                terminalCustomTitle=OpenCode
                ---
                marker=\(olderAppSession.marker)
                terminalWindowID=7
                terminalTabTTY=/dev/ttys007
                terminalCustomTitle=OpenCode
                """
            }

            return """
            found=true
            ---
            marker=\(olderAppSession.marker)
            terminalWindowID=7
            terminalTabTTY=/dev/ttys007
            terminalCustomTitle=\(olderAppSession.terminalTitle)
            ---
            marker=\(toolSession.marker)
            terminalWindowID=8
            terminalTabTTY=/dev/ttys008
            terminalCustomTitle=\(toolSession.terminalTitle)
            ---
            marker=\(latestAppSession.marker)
            terminalWindowID=9
            terminalTabTTY=/dev/ttys009
            terminalCustomTitle=\(latestAppSession.terminalTitle)
            """
        }
        let iTermController = ITermDriver { _ in
            XCTFail("iTerm2 should not be asked to focus Apple Terminal sessions.")
            return TerminalScriptFixtures.notFound
        }
        let controller = TerminalSessionController(drivers: [appleController, iTermController])

        let result = try controller.focusRunningSessions(from: [olderAppSession, latestAppSession])

        XCTAssertEqual(result.map(\.sessionID), ["latest-app", "older-app"])
        XCTAssertEqual(result.map(\.terminalWindowID), [9, 7])
        XCTAssertEqual(appleScripts.count, 2)
    }

    func testTerminalSessionControllerFocusesOnlyRequestedLiveSession() throws {
        let requestedSession = RunningTerminalSession(
            sessionID: "requested-session",
            marker: "WhereMyOpenCode:requested-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 12,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys012",
            terminalCustomTitle: "OpenCode"
        )
        let siblingSession = RunningTerminalSession(
            sessionID: "sibling-session",
            marker: "WhereMyOpenCode:sibling-session",
            terminalApp: .appleTerminal,
            terminalWindowID: 13,
            terminalSessionID: nil,
            terminalTabTTY: "/dev/ttys013",
            terminalCustomTitle: "OpenCode"
        )
        let appleController = AppleTerminalDriver { source in
            XCTAssertTrue(source.contains(requestedSession.marker))
            XCTAssertFalse(source.contains(siblingSession.marker))

            return """
            found=true
            ---
            marker=\(requestedSession.marker)
            terminalWindowID=12
            terminalTabTTY=/dev/ttys012
            terminalCustomTitle=OpenCode
            """
        }
        let controller = TerminalSessionController(drivers: [appleController, ITermDriver()])

        let result = try controller.focusRunningSessions([requestedSession])

        XCTAssertEqual(result.map(\.sessionID), ["requested-session"])
    }

    func testRaiseWindowMatchingHandlerOnlyRaisesByTitleMatch() {
        let handler = RaiseWindowHandler.source

        XCTAssertTrue(handler.contains("on raiseWindowMatching(processName, identifier)"))
        XCTAssertTrue(handler.contains("if identifier is \"\" then return"))
        XCTAssertTrue(handler.contains("repeat with axWindow in windows"))
        XCTAssertTrue(handler.contains("set windowTitle to title of axWindow"))
        XCTAssertTrue(handler.contains("if windowTitle contains identifier"))
        XCTAssertTrue(handler.contains("perform action \"AXRaise\" of axWindow"))
        XCTAssertFalse(handler.contains("perform action \"AXRaise\" of window 1"))
        XCTAssertFalse(handler.contains("activate"))
        XCTAssertFalse(handler.contains("set frontmost to true"))
    }

    func testTerminalSessionControllerFocusProjectSessionsScriptOmitsOtherProjectMarkers() throws {
        let projectAOlder = TrackedSession(
            id: "project-a-older",
            projectName: "ProjectA",
            projectPath: "/tmp/ProjectA",
            openedAt: Date(timeIntervalSince1970: 100),
            terminalApp: .iTerm2,
            terminalWindowID: 31,
            terminalSessionID: "iterm-project-a-older",
            terminalTabTTY: "/dev/ttys031",
            terminalCustomTitle: "OpenCode"
        )
        let projectALatest = TrackedSession(
            id: "project-a-latest",
            projectName: "ProjectA",
            projectPath: "/tmp/ProjectA",
            openedAt: Date(timeIntervalSince1970: 300),
            terminalApp: .iTerm2,
            terminalWindowID: 32,
            terminalSessionID: "iterm-project-a-latest",
            terminalTabTTY: "/dev/ttys032",
            terminalCustomTitle: "OpenCode"
        )
        let projectBSession = TrackedSession(
            id: "project-b",
            projectName: "ProjectB",
            projectPath: "/tmp/ProjectB",
            openedAt: Date(timeIntervalSince1970: 400),
            terminalApp: .iTerm2,
            terminalWindowID: 33,
            terminalSessionID: "iterm-project-b",
            terminalTabTTY: "/dev/ttys033",
            terminalCustomTitle: "OpenCode"
        )

        var iTermScripts: [String] = []
        let appleController = AppleTerminalDriver { _ in
            TerminalScriptFixtures.notFound
        }
        let iTermController = ITermDriver { source in
            iTermScripts.append(source)

            if source.contains("markersToFind") {
                XCTAssertTrue(source.contains(projectAOlder.marker))
                XCTAssertTrue(source.contains(projectALatest.marker))
                XCTAssertFalse(
                    source.contains(projectBSession.marker),
                    "Project B's marker must not appear in the focus script for Project A."
                )
                XCTAssertFalse(
                    source.contains(projectBSession.terminalSessionID ?? "<missing>"),
                    "Project B's terminal session ID must not appear in Project A's focus script."
                )

                return """
                found=true
                ---
                marker=\(projectALatest.marker)
                terminalWindowID=32
                terminalSessionID=iterm-project-a-latest
                terminalTabTTY=/dev/ttys032
                terminalCustomTitle=OpenCode
                ---
                marker=\(projectAOlder.marker)
                terminalWindowID=31
                terminalSessionID=iterm-project-a-older
                terminalTabTTY=/dev/ttys031
                terminalCustomTitle=OpenCode
                """
            }

            return """
            found=true
            ---
            terminalWindowID=31
            terminalSessionID=iterm-project-a-older
            terminalTabTTY=/dev/ttys031
            terminalCustomTitle=OpenCode
            ---
            terminalWindowID=32
            terminalSessionID=iterm-project-a-latest
            terminalTabTTY=/dev/ttys032
            terminalCustomTitle=OpenCode
            ---
            terminalWindowID=33
            terminalSessionID=iterm-project-b
            terminalTabTTY=/dev/ttys033
            terminalCustomTitle=OpenCode
            """
        }
        let controller = TerminalSessionController(drivers: [appleController, iTermController])

        let result = try controller.focusRunningSessions(from: [projectAOlder, projectALatest])

        XCTAssertEqual(result.map(\.sessionID), ["project-a-latest", "project-a-older"])
        XCTAssertEqual(result.map(\.terminalWindowID), [32, 31])
        XCTAssertEqual(iTermScripts.count, 2)

        let focusScript = try XCTUnwrap(iTermScripts.first { $0.contains("markersToFind") })
        XCTAssertTrue(focusScript.contains("my raiseWindowMatching(\"iTerm2\", markerText)"))
        XCTAssertFalse(focusScript.contains("perform action \"AXRaise\" of window 1"))
        XCTAssertFalse(focusScript.contains(projectBSession.marker))
    }
}
