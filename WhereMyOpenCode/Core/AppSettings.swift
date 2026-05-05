import Foundation

struct AppSettings: Codable, Equatable {
    static let defaultScanDepth = 2

    var rootFolderPath: String?
    var scanDepth: Int
    var opencodePath: String?
    var terminalApp: TerminalApp

    init(
        rootFolderPath: String? = nil,
        scanDepth: Int = Self.defaultScanDepth,
        opencodePath: String? = nil,
        terminalApp: TerminalApp = .appleTerminal
    ) {
        self.rootFolderPath = rootFolderPath
        self.scanDepth = scanDepth
        self.opencodePath = opencodePath
        self.terminalApp = terminalApp
    }
}

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case appleTerminal

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .appleTerminal:
            "Apple Terminal"
        }
    }
}
