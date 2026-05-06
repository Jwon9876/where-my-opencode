protocol TerminalSessionDriver {
    var terminalApp: TerminalApp { get }

    func runningSessions(from sessions: [TrackedSession]) throws -> [RunningTerminalSession]
    func focusRunningSessions(_ sessions: [RunningTerminalSession]) throws -> [RunningTerminalSession]
}
