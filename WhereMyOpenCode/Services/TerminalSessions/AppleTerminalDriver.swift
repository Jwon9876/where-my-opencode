struct AppleTerminalDriver: TerminalSessionDriver {
    typealias ScriptRunner = (String) throws -> String
    typealias WindowRaiser = (TerminalApp, String) -> Void

    let terminalApp: TerminalApp = .appleTerminal

    private let runAppleScript: ScriptRunner
    private let raiseWindow: WindowRaiser

    init(
        runAppleScript: @escaping ScriptRunner = AppleScriptRunner(
            preparationFailureMessage: "Could not prepare the Terminal focus command.",
            executionFailureFallbackMessage: "Terminal did not accept the focus command.",
            makeError: { TerminalSessionError.appleScriptFailed($0) }
        ).run,
        raiseWindow: @escaping WindowRaiser = TerminalWindowRaiser.raise
    ) {
        self.runAppleScript = runAppleScript
        self.raiseWindow = raiseWindow
    }

    func focusFirstRunningSession(from sessions: [TrackedSession]) throws -> RunningTerminalSession? {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return nil
        }

        let arguments = Self.focusArguments(from: candidateSessions)
        let payload = try runAppleScript(
            focusScript(markers: arguments.markers, windowIDs: arguments.windowIDs, ttys: arguments.ttys)
        )
        let runningSessions = runningTerminalSessions(payload: payload, sessions: candidateSessions)
        runningSessions.forEach { raiseWindow(.appleTerminal, $0.marker) }

        return runningSessions.first
    }

    func focusRunningSessions(_ sessions: [RunningTerminalSession]) throws -> [RunningTerminalSession] {
        let candidateSessions = Self.candidateRunningSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return []
        }

        let arguments = Self.focusArguments(from: candidateSessions)
        let payload = try runAppleScript(
            focusScript(markers: arguments.markers, windowIDs: arguments.windowIDs, ttys: arguments.ttys)
        )
        let runningSessions = runningTerminalSessions(payload: payload, runningSessions: candidateSessions)
        runningSessions.forEach { raiseWindow(.appleTerminal, $0.marker) }

        return runningSessions
    }

    func runningSessions(from sessions: [TrackedSession]) throws -> [RunningTerminalSession] {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return []
        }

        let payload = try runAppleScript(inventoryScript())

        return runningTerminalSessions(payload: payload, sessions: candidateSessions)
    }

    func focusScript(
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
        set payloadParts to {}

        tell application "Terminal"
            repeat with candidateIndex from 1 to count of markersToFind
                set markerText to item candidateIndex of markersToFind
                set expectedWindowID to item candidateIndex of windowIDsToFind
                set expectedTTY to item candidateIndex of ttysToFind
                set candidateMatched to false

                repeat with terminalWindow in windows
                    if candidateMatched is false then
                        repeat with terminalTab in tabs of terminalWindow
                            if candidateMatched is false then
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

                                    my raiseWindowMatching("Terminal", markerText)

                                    set end of payloadParts to "marker=" & markerText & linefeed & "terminalWindowID=" & focusedWindowID & linefeed & "terminalTabTTY=" & focusedTTY & linefeed & "terminalCustomTitle=" & terminalCustomTitle
                                    set candidateMatched to true
                                end if
                            end if
                        end repeat
                    end if
                end repeat
            end repeat
        end tell

        if (count of payloadParts) is 0 then
            return "found=false"
        end if

        set oldDelimiters to AppleScript's text item delimiters
        set AppleScript's text item delimiters to linefeed & "---" & linefeed
        set focusedPayload to payloadParts as text
        set AppleScript's text item delimiters to oldDelimiters

        return "found=true" & linefeed & "---" & linefeed & focusedPayload
        \(RaiseWindowHandler.source)
        """
    }

    func inventoryScript() -> String {
        """
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

    func runningTerminalSessions(payload: String, sessions: [TrackedSession]) -> [RunningTerminalSession] {
        let records = KeyValuePayload.parseRecords(payload)

        guard records.first?["found"] == "true" else {
            return []
        }

        let candidateSessions = Self.candidateSessions(from: sessions)
        let terminalRecords = records.count == 1 ? records : Array(records.dropFirst())

        return candidateSessions.compactMap { session in
            guard let values = terminalRecords.first(where: { TerminalSessionMatcher.record($0, matches: session) }) else {
                return nil
            }

            return makeRunningTerminalSession(values: values, session: session)
        }
    }

    func runningTerminalSessions(
        payload: String,
        runningSessions: [RunningTerminalSession]
    ) -> [RunningTerminalSession] {
        let records = KeyValuePayload.parseRecords(payload)

        guard records.first?["found"] == "true" else {
            return []
        }

        let candidateSessions = Self.candidateRunningSessions(from: runningSessions)
        let terminalRecords = records.count == 1 ? records : Array(records.dropFirst())

        return candidateSessions.compactMap { session in
            guard let values = terminalRecords.first(where: { TerminalSessionMatcher.record($0, matches: session) }) else {
                return nil
            }

            return makeRunningTerminalSession(values: values, runningSession: session)
        }
    }

    private func makeRunningTerminalSession(
        values: [String: String],
        session: TrackedSession
    ) -> RunningTerminalSession {
        RunningTerminalSession(
            sessionID: session.id,
            marker: session.marker,
            terminalApp: .appleTerminal,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalSessionID: nil,
            terminalTabTTY: KeyValuePayload.nonEmpty(values["terminalTabTTY"]),
            terminalCustomTitle: KeyValuePayload.nonEmpty(values["terminalCustomTitle"])
        )
    }

    private func makeRunningTerminalSession(
        values: [String: String],
        runningSession: RunningTerminalSession
    ) -> RunningTerminalSession {
        RunningTerminalSession(
            sessionID: runningSession.sessionID,
            marker: runningSession.marker,
            terminalApp: .appleTerminal,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalSessionID: nil,
            terminalTabTTY: KeyValuePayload.nonEmpty(values["terminalTabTTY"]),
            terminalCustomTitle: KeyValuePayload.nonEmpty(values["terminalCustomTitle"])
        )
    }

    private static func candidateSessions(from sessions: [TrackedSession]) -> [TrackedSession] {
        sessions
            .filter { $0.terminalApp == nil || $0.terminalApp == .appleTerminal }
            .sorted(by: TerminalSessionMatcher.sortMostRecentFirst)
    }

    private static func candidateRunningSessions(
        from sessions: [RunningTerminalSession]
    ) -> [RunningTerminalSession] {
        sessions.filter { $0.terminalApp == .appleTerminal }
    }

    private static func focusArguments(
        from sessions: [TrackedSession]
    ) -> (markers: [String], windowIDs: [String], ttys: [String]) {
        (
            markers: sessions.map(\.marker),
            windowIDs: sessions.map { $0.terminalWindowID.map(String.init) ?? "" },
            ttys: sessions.map { $0.terminalTabTTY ?? "" }
        )
    }

    private static func focusArguments(
        from sessions: [RunningTerminalSession]
    ) -> (markers: [String], windowIDs: [String], ttys: [String]) {
        (
            markers: sessions.map(\.marker),
            windowIDs: sessions.map { $0.terminalWindowID.map(String.init) ?? "" },
            ttys: sessions.map { $0.terminalTabTTY ?? "" }
        )
    }
}
