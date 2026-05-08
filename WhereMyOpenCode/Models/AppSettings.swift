import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var rootFolderPath: String?
    var opencodePath: String?
    var terminalApp: TerminalApp

    init(
        rootFolderPath: String? = nil,
        opencodePath: String? = nil,
        terminalApp: TerminalApp = .appleTerminal
    ) {
        self.rootFolderPath = rootFolderPath
        self.opencodePath = opencodePath
        self.terminalApp = terminalApp
    }
}

enum TerminalApp: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleTerminal
    case iTerm2

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .appleTerminal:
            "Apple Terminal"
        case .iTerm2:
            "iTerm2"
        }
    }
}
