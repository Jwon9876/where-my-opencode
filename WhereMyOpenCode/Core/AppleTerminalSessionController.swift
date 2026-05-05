import Foundation

struct RunningTerminalSession: Equatable {
    let sessionID: String
    let marker: String
    let terminalWindowID: Int?
    let terminalTabTTY: String?
    let terminalCustomTitle: String?
}

struct AppleTerminalSessionController {
    typealias ScriptRunner = (String) throws -> String

    private let runAppleScript: ScriptRunner

    init(runAppleScript: @escaping ScriptRunner = AppleTerminalSessionController.runAppleScript) {
        self.runAppleScript = runAppleScript
    }

    func focusFirstRunningSession(from sessions: [TrackedSession]) throws -> RunningTerminalSession? {
        let candidateSessions = sessions
            .filter { $0.terminalApp == nil || $0.terminalApp == .appleTerminal }
            .sorted(by: Self.sortMostRecentFirst)

        guard !candidateSessions.isEmpty else {
            return nil
        }

        let payload = try runAppleScript(
            appleTerminalFocusScript(markers: candidateSessions.map(\.marker))
        )

        return runningTerminalSession(payload: payload, sessions: candidateSessions)
    }

    func appleTerminalFocusScript(markers: [String]) -> String {
        let markerList = markers
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")

        return """
        if application "Terminal" is not running then
            return "found=false"
        end if

        set markersToFind to {\(markerList)}

        tell application "Terminal"
            repeat with markerValue in markersToFind
                set markerText to markerValue as text

                repeat with terminalWindow in windows
                    repeat with terminalTab in tabs of terminalWindow
                        set terminalCustomTitle to ""

                        try
                            set terminalCustomTitle to custom title of terminalTab
                        end try

                        if terminalCustomTitle is markerText or terminalCustomTitle begins with markerText & " " then
                            set selected tab of terminalWindow to terminalTab
                            set index of terminalWindow to 1

                            set focusedWindowID to ""
                            set focusedTTY to ""

                            try
                                set focusedWindowID to (id of terminalWindow as text)
                            end try

                            try
                                set focusedTTY to tty of terminalTab
                            end try

                            activate

                            return "found=true" & linefeed & "marker=" & markerText & linefeed & "terminalWindowID=" & focusedWindowID & linefeed & "terminalTabTTY=" & focusedTTY & linefeed & "terminalCustomTitle=" & terminalCustomTitle
                        end if
                    end repeat
                end repeat
            end repeat
        end tell

        return "found=false"
        """
    }

    func runningTerminalSession(payload: String, sessions: [TrackedSession]) -> RunningTerminalSession? {
        let values = Self.keyValuePayload(payload)

        guard values["found"] == "true",
              let marker = Self.nonEmptyValue(values["marker"]),
              let session = sessions.first(where: { $0.marker == marker }) else {
            return nil
        }

        return RunningTerminalSession(
            sessionID: session.id,
            marker: marker,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalTabTTY: Self.nonEmptyValue(values["terminalTabTTY"]),
            terminalCustomTitle: Self.nonEmptyValue(values["terminalCustomTitle"])
        )
    }

    private static func runAppleScript(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleTerminalSessionControllerError.appleScriptFailed(
                "Could not prepare the Terminal focus command."
            )
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
            throw AppleTerminalSessionControllerError.appleScriptFailed(
                message ?? "Terminal did not accept the focus command."
            )
        }

        return result.stringValue ?? ""
    }

    private static func keyValuePayload(_ payload: String) -> [String: String] {
        payload
            .components(separatedBy: .newlines)
            .reduce(into: [String: String]()) { partialResult, line in
                guard let separatorIndex = line.firstIndex(of: "=") else {
                    return
                }

                let key = String(line[..<separatorIndex])
                let valueStartIndex = line.index(after: separatorIndex)
                partialResult[key] = String(line[valueStartIndex...])
            }
    }

    private static func sortMostRecentFirst(lhs: TrackedSession, rhs: TrackedSession) -> Bool {
        if lhs.openedAt == rhs.openedAt {
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        return lhs.openedAt > rhs.openedAt
    }

    private static func nonEmptyValue(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }
}

enum AppleTerminalSessionControllerError: LocalizedError {
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .appleScriptFailed(let message):
            "Could not focus Terminal: \(message)"
        }
    }
}
