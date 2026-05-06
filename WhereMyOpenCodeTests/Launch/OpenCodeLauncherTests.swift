import Foundation
import XCTest
@testable import Where_My_OpenCode

final class OpenCodeLauncherTests: XCTestCase {
    func testOpenCodeLauncherBuildsEscapedCommandAndTerminalTitleScript() {
        let launcher = OpenCodeLauncher()
        let command = launcher.terminalCommand(
            projectPath: "/tmp/John's App",
            opencodePath: "/usr/local/bin/open code"
        )
        let script = AppleTerminalLauncher().script(
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
        let script = AppleTerminalLauncher().script(
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
        let script = ITermLauncher().script(
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
        let script = ITermLauncher().script(
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
        let launchedAt = Date(timeIntervalSince1970: 500)
        let result = OpenCodeLaunchResult.parse(
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
        let launchedAt = Date(timeIntervalSince1970: 600)
        let result = OpenCodeLaunchResult.parse(
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

    func testOpenCodeLauncherLaunchScriptsRaiseOnlyMarkedWindow() {
        let appleScript = AppleTerminalLauncher().script(
            command: "echo hi",
            terminalTitle: "WhereMyOpenCode:abc Demo",
            marker: "WhereMyOpenCode:abc"
        )
        let iTermScript = ITermLauncher().script(
            command: "echo hi",
            terminalTitle: "WhereMyOpenCode:abc Demo",
            marker: "WhereMyOpenCode:abc"
        )

        for script in [appleScript, iTermScript] {
            XCTAssertTrue(script.contains("if windowTitle contains identifier"))
            XCTAssertTrue(script.contains("perform action \"AXRaise\" of axWindow"))
            XCTAssertFalse(script.contains("perform action \"AXRaise\" of window 1"))
            XCTAssertFalse(script.contains("raiseSelectedWindow"))
            XCTAssertFalse(script.contains("activate"))
        }

        XCTAssertTrue(appleScript.contains("my raiseWindowMatching(\"Terminal\", \"WhereMyOpenCode:abc\")"))
        XCTAssertTrue(iTermScript.contains("my raiseWindowMatching(\"iTerm2\", \"WhereMyOpenCode:abc\")"))
    }

    func testOpenCodeLauncherLaunchScriptsWithoutFocusContainNoRaiseCalls() {
        let appleScript = AppleTerminalLauncher().script(
            command: "echo hi",
            terminalTitle: "WhereMyOpenCode:abc Demo",
            marker: "WhereMyOpenCode:abc",
            focusPolicy: .none
        )
        let iTermScript = ITermLauncher().script(
            command: "echo hi",
            terminalTitle: "WhereMyOpenCode:abc Demo",
            marker: "WhereMyOpenCode:abc",
            focusPolicy: .none
        )

        for script in [appleScript, iTermScript] {
            XCTAssertFalse(script.contains("activate"))
            XCTAssertFalse(script.contains("AXRaise"))
            XCTAssertFalse(script.contains("raiseWindowMatching"))
            XCTAssertFalse(script.contains("raiseSelectedWindow"))
            XCTAssertFalse(script.contains("set frontmost to true"))
        }
    }
}
