import Foundation

struct RunningTerminalSession: Equatable, Sendable {
    let sessionID: String
    let marker: String
    let terminalApp: TerminalApp
    let terminalWindowID: Int?
    let terminalSessionID: String?
    let terminalTabTTY: String?
    let terminalCustomTitle: String?
}

struct TerminalSessionController {
    private let appleTerminalSessionController: AppleTerminalSessionController
    private let iTermSessionController: ITermSessionController

    init(
        appleTerminalSessionController: AppleTerminalSessionController = AppleTerminalSessionController(),
        iTermSessionController: ITermSessionController = ITermSessionController()
    ) {
        self.appleTerminalSessionController = appleTerminalSessionController
        self.iTermSessionController = iTermSessionController
    }

    func focusFirstRunningSession(from sessions: [TrackedSession]) throws -> RunningTerminalSession? {
        let runningSessions = try runningSessions(from: sessions)

        guard let runningSession = runningSessions.first,
              let session = sessions.first(where: { $0.id == runningSession.sessionID }) else {
            return nil
        }

        switch runningSession.terminalApp {
        case .appleTerminal:
            return try appleTerminalSessionController.focusFirstRunningSession(from: [session])
        case .iTerm2:
            return try iTermSessionController.focusFirstRunningSession(from: [session])
        }
    }

    func runningSessions(from sessions: [TrackedSession]) throws -> [RunningTerminalSession] {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return []
        }

        let runningSessions = try appleTerminalSessionController.runningSessions(from: candidateSessions)
            + iTermSessionController.runningSessions(from: candidateSessions)
        let orderBySessionID = Dictionary(
            uniqueKeysWithValues: candidateSessions.enumerated().map { ($0.element.id, $0.offset) }
        )

        return runningSessions.sorted {
            orderBySessionID[$0.sessionID, default: Int.max] < orderBySessionID[$1.sessionID, default: Int.max]
        }
    }

    private static func candidateSessions(from sessions: [TrackedSession]) -> [TrackedSession] {
        sessions
            .filter { $0.terminalApp == nil || $0.terminalApp == .appleTerminal || $0.terminalApp == .iTerm2 }
            .sorted(by: sortMostRecentFirst)
    }

    private static func sortMostRecentFirst(lhs: TrackedSession, rhs: TrackedSession) -> Bool {
        if lhs.openedAt == rhs.openedAt {
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        return lhs.openedAt > rhs.openedAt
    }
}

struct AppleTerminalSessionController {
    typealias ScriptRunner = (String) throws -> String

    private let runAppleScript: ScriptRunner

    init(runAppleScript: @escaping ScriptRunner = AppleTerminalSessionController.runAppleScript) {
        self.runAppleScript = runAppleScript
    }

    func focusFirstRunningSession(from sessions: [TrackedSession]) throws -> RunningTerminalSession? {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return nil
        }

        let payload = try runAppleScript(
            appleTerminalFocusScript(sessions: candidateSessions)
        )

        return runningTerminalSession(payload: payload, sessions: candidateSessions)
    }

    func runningSessions(from sessions: [TrackedSession]) throws -> [RunningTerminalSession] {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return []
        }

        let payload = try runAppleScript(
            appleTerminalInventoryScript(sessions: candidateSessions)
        )

        return runningTerminalSessions(payload: payload, sessions: candidateSessions)
    }

    func appleTerminalFocusScript(markers: [String]) -> String {
        appleTerminalFocusScript(
            markers: markers,
            windowIDs: Array(repeating: "", count: markers.count),
            ttys: Array(repeating: "", count: markers.count)
        )
    }

    func appleTerminalFocusScript(sessions: [TrackedSession]) -> String {
        appleTerminalFocusScript(
            markers: sessions.map(\.marker),
            windowIDs: sessions.map { $0.terminalWindowID.map(String.init) ?? "" },
            ttys: sessions.map { $0.terminalTabTTY ?? "" }
        )
    }

    private func appleTerminalFocusScript(
        markers: [String],
        windowIDs: [String],
        ttys: [String]
    ) -> String {
        let markerList = markers
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")
        let windowIDList = windowIDs
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")
        let ttyList = ttys
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")

        return """
        if application "Terminal" is not running then
            return "found=false"
        end if

        set markersToFind to {\(markerList)}
        set windowIDsToFind to {\(windowIDList)}
        set ttysToFind to {\(ttyList)}

        tell application "Terminal"
            repeat with candidateIndex from 1 to count of markersToFind
                set markerText to item candidateIndex of markersToFind
                set expectedWindowID to item candidateIndex of windowIDsToFind
                set expectedTTY to item candidateIndex of ttysToFind

                repeat with terminalWindow in windows
                    repeat with terminalTab in tabs of terminalWindow
                        set terminalWindowID to ""
                        set terminalCustomTitle to ""
                        set terminalTTY to ""

                        try
                            set terminalCustomTitle to custom title of terminalTab
                        end try

                        try
                            set terminalWindowID to (id of terminalWindow as text)
                        end try

                        try
                            set terminalTTY to tty of terminalTab
                        end try

                        set markerMatches to terminalCustomTitle is markerText or terminalCustomTitle begins with markerText & " "
                        set metadataMatches to false

                        if expectedWindowID is not "" and expectedTTY is not "" then
                            if terminalWindowID is expectedWindowID and terminalTTY is expectedTTY then
                                set metadataMatches to true
                            end if
                        else if expectedTTY is not "" then
                            if terminalTTY is expectedTTY then
                                set metadataMatches to true
                            end if
                        else if expectedWindowID is not "" then
                            if terminalWindowID is expectedWindowID then
                                set metadataMatches to true
                            end if
                        end if

                        if markerMatches or metadataMatches then
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

                            my raiseSelectedWindow("Terminal")

                            return "found=true" & linefeed & "marker=" & markerText & linefeed & "terminalWindowID=" & focusedWindowID & linefeed & "terminalTabTTY=" & focusedTTY & linefeed & "terminalCustomTitle=" & terminalCustomTitle
                        end if
                    end repeat
                end repeat
            end repeat
        end tell

        return "found=false"

        on raiseSelectedWindow(processName)
            try
                tell application "System Events"
                    if exists process processName then
                        tell process processName
                            perform action "AXRaise" of window 1
                        end tell
                    end if
                end tell
            end try
        end raiseSelectedWindow
        """
    }

    func appleTerminalInventoryScript(markers _: [String]) -> String {
        appleTerminalInventoryScript()
    }

    func appleTerminalInventoryScript(sessions _: [TrackedSession]) -> String {
        appleTerminalInventoryScript()
    }

    private func appleTerminalInventoryScript() -> String {
        return """
        if application "Terminal" is not running then
            return "found=false"
        end if

        set payloadParts to {}

        tell application "Terminal"
            repeat with terminalWindow in windows
                repeat with terminalTab in tabs of terminalWindow
                    set terminalWindowID to ""
                    set terminalTTY to ""
                    set terminalCustomTitle to ""

                    try
                        set terminalWindowID to (id of terminalWindow as text)
                    end try

                    try
                        set terminalTTY to tty of terminalTab
                    end try

                    try
                        set terminalCustomTitle to custom title of terminalTab
                    end try

                    set end of payloadParts to "terminalWindowID=" & terminalWindowID & linefeed & "terminalTabTTY=" & terminalTTY & linefeed & "terminalCustomTitle=" & terminalCustomTitle
                end repeat
            end repeat
        end tell

        if (count of payloadParts) is 0 then
            return "found=false"
        end if

        set oldDelimiters to AppleScript's text item delimiters
        set AppleScript's text item delimiters to linefeed & "---" & linefeed
        set inventoryPayload to payloadParts as text
        set AppleScript's text item delimiters to oldDelimiters

        return "found=true" & linefeed & "---" & linefeed & inventoryPayload
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
            terminalApp: .appleTerminal,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalSessionID: nil,
            terminalTabTTY: Self.nonEmptyValue(values["terminalTabTTY"]),
            terminalCustomTitle: Self.nonEmptyValue(values["terminalCustomTitle"])
        )
    }

    func runningTerminalSessions(payload: String, sessions: [TrackedSession]) -> [RunningTerminalSession] {
        let records = Self.keyValueRecords(payload)

        guard records.first?["found"] == "true" else {
            return []
        }

        let candidateSessions = Self.candidateSessions(from: sessions)
        let terminalRecords = records.count == 1 ? records : Array(records.dropFirst())

        return candidateSessions.compactMap { session in
            guard let values = terminalRecords.first(where: { Self.terminalRecord($0, matches: session) }) else {
                return nil
            }

            return RunningTerminalSession(
                sessionID: session.id,
                marker: session.marker,
                terminalApp: .appleTerminal,
                terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
                terminalSessionID: nil,
                terminalTabTTY: Self.nonEmptyValue(values["terminalTabTTY"]),
                terminalCustomTitle: Self.nonEmptyValue(values["terminalCustomTitle"])
            )
        }
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

    private static func candidateSessions(from sessions: [TrackedSession]) -> [TrackedSession] {
        sessions
            .filter { $0.terminalApp == nil || $0.terminalApp == .appleTerminal }
            .sorted(by: Self.sortMostRecentFirst)
    }

    private static func keyValueRecords(_ payload: String) -> [[String: String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []

        for line in payload.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                records.append(currentRecord)
                currentRecord = []
            } else {
                currentRecord.append(line)
            }
        }

        records.append(currentRecord)

        return records.map { keyValuePayload($0.joined(separator: "\n")) }
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

    private static func terminalRecord(_ values: [String: String], matches session: TrackedSession) -> Bool {
        if Self.nonEmptyValue(values["marker"]) == session.marker {
            return true
        }

        if let terminalCustomTitle = Self.nonEmptyValue(values["terminalCustomTitle"]),
           (terminalCustomTitle == session.marker || terminalCustomTitle.hasPrefix("\(session.marker) ")) {
            return true
        }

        let terminalWindowID = values["terminalWindowID"].flatMap(Int.init)
        let terminalTabTTY = Self.nonEmptyValue(values["terminalTabTTY"])

        if let expectedWindowID = session.terminalWindowID,
           let expectedTTY = session.terminalTabTTY {
            return terminalWindowID == expectedWindowID && terminalTabTTY == expectedTTY
        }

        if let expectedTTY = session.terminalTabTTY {
            return terminalTabTTY == expectedTTY
        }

        if let expectedWindowID = session.terminalWindowID {
            return terminalWindowID == expectedWindowID
        }

        return false
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

struct ITermSessionController {
    typealias ScriptRunner = (String) throws -> String

    private let runAppleScript: ScriptRunner

    init(runAppleScript: @escaping ScriptRunner = ITermSessionController.runAppleScript) {
        self.runAppleScript = runAppleScript
    }

    func focusFirstRunningSession(from sessions: [TrackedSession]) throws -> RunningTerminalSession? {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return nil
        }

        let payload = try runAppleScript(iTerm2FocusScript(sessions: candidateSessions))

        return runningTerminalSession(payload: payload, sessions: candidateSessions)
    }

    func runningSessions(from sessions: [TrackedSession]) throws -> [RunningTerminalSession] {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return []
        }

        let payload = try runAppleScript(iTerm2InventoryScript())

        return runningTerminalSessions(payload: payload, sessions: candidateSessions)
    }

    func iTerm2FocusScript(sessions: [TrackedSession]) -> String {
        iTerm2FocusScript(
            markers: sessions.map(\.marker),
            windowIDs: sessions.map { $0.terminalWindowID.map(String.init) ?? "" },
            sessionIDs: sessions.map { $0.terminalSessionID ?? "" },
            ttys: sessions.map { $0.terminalTabTTY ?? "" }
        )
    }

    func iTerm2FocusScript(
        markers: [String],
        windowIDs: [String],
        sessionIDs: [String],
        ttys: [String]
    ) -> String {
        let markerList = markers
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")
        let windowIDList = windowIDs
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")
        let sessionIDList = sessionIDs
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")
        let ttyList = ttys
            .map(AppleScriptSupport.stringLiteral)
            .joined(separator: ", ")

        return """
        if application id "com.googlecode.iterm2" is not running then
            return "found=false"
        end if

        set markersToFind to {\(markerList)}
        set windowIDsToFind to {\(windowIDList)}
        set sessionIDsToFind to {\(sessionIDList)}
        set ttysToFind to {\(ttyList)}

        tell application id "com.googlecode.iterm2"
            repeat with candidateIndex from 1 to count of markersToFind
                set markerText to item candidateIndex of markersToFind
                set expectedWindowID to item candidateIndex of windowIDsToFind
                set expectedSessionID to item candidateIndex of sessionIDsToFind
                set expectedTTY to item candidateIndex of ttysToFind

                repeat with terminalWindow in windows
                    set terminalWindowID to ""

                    try
                        set terminalWindowID to (id of terminalWindow as text)
                    end try

                    repeat with terminalTab in tabs of terminalWindow
                        repeat with terminalSession in sessions of terminalTab
                            set terminalSessionID to ""
                            set terminalTTY to ""
                            set terminalName to ""

                            try
                                set terminalSessionID to unique id of terminalSession
                            end try

                            try
                                set terminalTTY to tty of terminalSession
                            end try

                            try
                                set terminalName to name of terminalSession
                            end try

                            set markerMatches to terminalName is markerText or terminalName begins with markerText & " "
                            set metadataMatches to false

                            if expectedSessionID is not "" then
                                if terminalSessionID is expectedSessionID then
                                    set metadataMatches to true
                                end if
                            else if expectedWindowID is not "" and expectedTTY is not "" then
                                if terminalWindowID is expectedWindowID and terminalTTY is expectedTTY then
                                    set metadataMatches to true
                                end if
                            else if expectedTTY is not "" then
                                if terminalTTY is expectedTTY then
                                    set metadataMatches to true
                                end if
                            else if expectedWindowID is not "" then
                                if terminalWindowID is expectedWindowID then
                                    set metadataMatches to true
                                end if
                            end if

                            if markerMatches or metadataMatches then
                                select terminalSession
                                select terminalTab
                                select terminalWindow
                                my raiseSelectedWindow("iTerm2")

                                return "found=true" & linefeed & "marker=" & markerText & linefeed & "terminalWindowID=" & terminalWindowID & linefeed & "terminalSessionID=" & terminalSessionID & linefeed & "terminalTabTTY=" & terminalTTY & linefeed & "terminalCustomTitle=" & terminalName
                            end if
                        end repeat
                    end repeat
                end repeat
            end repeat
        end tell

        return "found=false"

        on raiseSelectedWindow(processName)
            try
                tell application "System Events"
                    if exists process processName then
                        tell process processName
                            perform action "AXRaise" of window 1
                        end tell
                    end if
                end tell
            end try
        end raiseSelectedWindow
        """
    }

    func iTerm2InventoryScript() -> String {
        """
        if application id "com.googlecode.iterm2" is not running then
            return "found=false"
        end if

        set payloadParts to {}

        tell application id "com.googlecode.iterm2"
            repeat with terminalWindow in windows
                set terminalWindowID to ""

                try
                    set terminalWindowID to (id of terminalWindow as text)
                end try

                repeat with terminalTab in tabs of terminalWindow
                    repeat with terminalSession in sessions of terminalTab
                        set terminalSessionID to ""
                        set terminalTTY to ""
                        set terminalName to ""

                        try
                            set terminalSessionID to unique id of terminalSession
                        end try

                        try
                            set terminalTTY to tty of terminalSession
                        end try

                        try
                            set terminalName to name of terminalSession
                        end try

                        set end of payloadParts to "terminalWindowID=" & terminalWindowID & linefeed & "terminalSessionID=" & terminalSessionID & linefeed & "terminalTabTTY=" & terminalTTY & linefeed & "terminalCustomTitle=" & terminalName
                    end repeat
                end repeat
            end repeat
        end tell

        if (count of payloadParts) is 0 then
            return "found=false"
        end if

        set oldDelimiters to AppleScript's text item delimiters
        set AppleScript's text item delimiters to linefeed & "---" & linefeed
        set inventoryPayload to payloadParts as text
        set AppleScript's text item delimiters to oldDelimiters

        return "found=true" & linefeed & "---" & linefeed & inventoryPayload
        """
    }

    func runningTerminalSession(payload: String, sessions: [TrackedSession]) -> RunningTerminalSession? {
        let values = Self.keyValuePayload(payload)

        guard values["found"] == "true",
              let marker = Self.nonEmptyValue(values["marker"]),
              let session = sessions.first(where: { $0.marker == marker }) else {
            return nil
        }

        return runningTerminalSession(values: values, session: session)
    }

    func runningTerminalSessions(payload: String, sessions: [TrackedSession]) -> [RunningTerminalSession] {
        let records = Self.keyValueRecords(payload)

        guard records.first?["found"] == "true" else {
            return []
        }

        let candidateSessions = Self.candidateSessions(from: sessions)
        let terminalRecords = records.count == 1 ? records : Array(records.dropFirst())

        return candidateSessions.compactMap { session in
            guard let values = terminalRecords.first(where: { Self.terminalRecord($0, matches: session) }) else {
                return nil
            }

            return runningTerminalSession(values: values, session: session)
        }
    }

    private func runningTerminalSession(
        values: [String: String],
        session: TrackedSession
    ) -> RunningTerminalSession {
        RunningTerminalSession(
            sessionID: session.id,
            marker: session.marker,
            terminalApp: .iTerm2,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalSessionID: Self.nonEmptyValue(values["terminalSessionID"]),
            terminalTabTTY: Self.nonEmptyValue(values["terminalTabTTY"]),
            terminalCustomTitle: Self.nonEmptyValue(values["terminalCustomTitle"])
        )
    }

    private static func runAppleScript(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleTerminalSessionControllerError.appleScriptFailed(
                "Could not prepare the iTerm2 focus command."
            )
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
            throw AppleTerminalSessionControllerError.appleScriptFailed(
                message ?? "iTerm2 did not accept the focus command."
            )
        }

        return result.stringValue ?? ""
    }

    private static func candidateSessions(from sessions: [TrackedSession]) -> [TrackedSession] {
        sessions
            .filter { $0.terminalApp == .iTerm2 }
            .sorted(by: Self.sortMostRecentFirst)
    }

    private static func keyValueRecords(_ payload: String) -> [[String: String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []

        for line in payload.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                records.append(currentRecord)
                currentRecord = []
            } else {
                currentRecord.append(line)
            }
        }

        records.append(currentRecord)

        return records.map { keyValuePayload($0.joined(separator: "\n")) }
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

    private static func terminalRecord(_ values: [String: String], matches session: TrackedSession) -> Bool {
        if Self.nonEmptyValue(values["terminalMarker"]) == session.marker {
            return true
        }

        if let terminalSessionID = Self.nonEmptyValue(values["terminalSessionID"]),
           let expectedSessionID = session.terminalSessionID,
           terminalSessionID == expectedSessionID {
            return true
        }

        if let terminalName = Self.nonEmptyValue(values["terminalCustomTitle"]),
           (terminalName == session.marker || terminalName.hasPrefix("\(session.marker) ")) {
            return true
        }

        let terminalWindowID = values["terminalWindowID"].flatMap(Int.init)
        let terminalTabTTY = Self.nonEmptyValue(values["terminalTabTTY"])

        if let expectedWindowID = session.terminalWindowID,
           let expectedTTY = session.terminalTabTTY {
            return terminalWindowID == expectedWindowID && terminalTabTTY == expectedTTY
        }

        if let expectedTTY = session.terminalTabTTY {
            return terminalTabTTY == expectedTTY
        }

        if let expectedWindowID = session.terminalWindowID {
            return terminalWindowID == expectedWindowID
        }

        return false
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
