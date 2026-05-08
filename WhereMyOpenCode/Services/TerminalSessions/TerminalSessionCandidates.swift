enum TerminalSessionCandidates {
    static func tracked(
        from sessions: [TrackedSession],
        terminalApp: TerminalApp
    ) -> [TrackedSession] {
        sessions
            .filter { session in
                switch terminalApp {
                case .appleTerminal:
                    session.terminalApp == nil || session.terminalApp == .appleTerminal
                case .iTerm2:
                    session.terminalApp == .iTerm2
                }
            }
            .sorted(by: TerminalSessionMatcher.sortMostRecentFirst)
    }

    static func running(
        from sessions: [RunningTerminalSession],
        terminalApp: TerminalApp
    ) -> [RunningTerminalSession] {
        sessions.filter { $0.terminalApp == terminalApp }
    }
}
