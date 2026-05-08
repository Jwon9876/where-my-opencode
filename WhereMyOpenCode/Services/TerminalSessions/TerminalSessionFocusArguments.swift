struct TerminalSessionFocusArguments {
    let markers: [String]
    let windowIDs: [String]
    let sessionIDs: [String]
    let ttys: [String]

    init(sessions: [TrackedSession]) {
        self.markers = sessions.map(\.marker)
        self.windowIDs = sessions.map { $0.terminalWindowID.map(String.init) ?? "" }
        self.sessionIDs = sessions.map { $0.terminalSessionID ?? "" }
        self.ttys = sessions.map { $0.terminalTabTTY ?? "" }
    }

    init(sessions: [RunningTerminalSession]) {
        self.markers = sessions.map(\.marker)
        self.windowIDs = sessions.map { $0.terminalWindowID.map(String.init) ?? "" }
        self.sessionIDs = sessions.map { $0.terminalSessionID ?? "" }
        self.ttys = sessions.map { $0.terminalTabTTY ?? "" }
    }
}
