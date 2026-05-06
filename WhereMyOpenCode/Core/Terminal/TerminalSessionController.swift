struct TerminalSessionController {
    private let drivers: [any TerminalSessionDriver]

    init(
        drivers: [any TerminalSessionDriver] = [
            AppleTerminalDriver(),
            ITermDriver()
        ]
    ) {
        self.drivers = drivers
    }

    func focusFirstRunningSession(from sessions: [TrackedSession]) throws -> RunningTerminalSession? {
        guard let runningSession = try runningSessions(from: sessions).first else {
            return nil
        }

        return try focusRunningSessions([runningSession]).first
    }

    func focusRunningSessions(from sessions: [TrackedSession]) throws -> [RunningTerminalSession] {
        try focusRunningSessions(runningSessions(from: sessions))
    }

    func focusRunningSessions(_ sessions: [RunningTerminalSession]) throws -> [RunningTerminalSession] {
        let candidateSessions = sessions.filter {
            $0.terminalApp == .appleTerminal || $0.terminalApp == .iTerm2
        }

        guard !candidateSessions.isEmpty else {
            return []
        }

        let focusedSessions = try drivers.flatMap { driver in
            try driver.focusRunningSessions(candidateSessions)
        }
        let orderBySessionID = Dictionary(
            uniqueKeysWithValues: candidateSessions.enumerated().map { ($0.element.sessionID, $0.offset) }
        )

        return focusedSessions.sorted {
            orderBySessionID[$0.sessionID, default: Int.max] < orderBySessionID[$1.sessionID, default: Int.max]
        }
    }

    func runningSessions(from sessions: [TrackedSession]) throws -> [RunningTerminalSession] {
        let candidateSessions = Self.candidateSessions(from: sessions)

        guard !candidateSessions.isEmpty else {
            return []
        }

        let runningSessions = try drivers.flatMap { driver in
            try driver.runningSessions(from: candidateSessions)
        }
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
            .sorted(by: TerminalSessionMatcher.sortMostRecentFirst)
    }
}
