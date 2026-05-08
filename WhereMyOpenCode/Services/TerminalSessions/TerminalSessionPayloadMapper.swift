enum TerminalSessionPayloadMapper {
    static func runningSessions(
        payload: String,
        sessions: [TrackedSession],
        terminalApp: TerminalApp
    ) -> [RunningTerminalSession] {
        let candidateSessions = TerminalSessionCandidates.tracked(from: sessions, terminalApp: terminalApp)
        let terminalRecords = matchingRecords(from: payload)

        guard !terminalRecords.isEmpty else {
            return []
        }

        return candidateSessions.compactMap { session in
            guard let values = terminalRecords.first(where: { TerminalSessionMatcher.record($0, matches: session) }) else {
                return nil
            }

            return makeRunningTerminalSession(values: values, session: session, terminalApp: terminalApp)
        }
    }

    static func runningSessions(
        payload: String,
        sessions: [RunningTerminalSession],
        terminalApp: TerminalApp
    ) -> [RunningTerminalSession] {
        let candidateSessions = TerminalSessionCandidates.running(from: sessions, terminalApp: terminalApp)
        let terminalRecords = matchingRecords(from: payload)

        guard !terminalRecords.isEmpty else {
            return []
        }

        return candidateSessions.compactMap { session in
            guard let values = terminalRecords.first(where: { TerminalSessionMatcher.record($0, matches: session) }) else {
                return nil
            }

            return makeRunningTerminalSession(values: values, session: session, terminalApp: terminalApp)
        }
    }

    private static func matchingRecords(from payload: String) -> [[String: String]] {
        let records = KeyValuePayload.parseRecords(payload)

        guard records.first?["found"] == "true" else {
            return []
        }

        return records.count == 1 ? records : Array(records.dropFirst())
    }

    private static func makeRunningTerminalSession(
        values: [String: String],
        session: TrackedSession,
        terminalApp: TerminalApp
    ) -> RunningTerminalSession {
        RunningTerminalSession(
            sessionID: session.id,
            marker: session.marker,
            terminalApp: terminalApp,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalSessionID: terminalSessionID(from: values, terminalApp: terminalApp),
            terminalTabTTY: KeyValuePayload.nonEmpty(values["terminalTabTTY"]),
            terminalCustomTitle: KeyValuePayload.nonEmpty(values["terminalCustomTitle"])
        )
    }

    private static func makeRunningTerminalSession(
        values: [String: String],
        session: RunningTerminalSession,
        terminalApp: TerminalApp
    ) -> RunningTerminalSession {
        RunningTerminalSession(
            sessionID: session.sessionID,
            marker: session.marker,
            terminalApp: terminalApp,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalSessionID: terminalSessionID(from: values, terminalApp: terminalApp),
            terminalTabTTY: KeyValuePayload.nonEmpty(values["terminalTabTTY"]),
            terminalCustomTitle: KeyValuePayload.nonEmpty(values["terminalCustomTitle"])
        )
    }

    private static func terminalSessionID(
        from values: [String: String],
        terminalApp: TerminalApp
    ) -> String? {
        switch terminalApp {
        case .appleTerminal:
            nil
        case .iTerm2:
            KeyValuePayload.nonEmpty(values["terminalSessionID"])
        }
    }
}
