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
