import Foundation

enum TerminalSessionError: LocalizedError {
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .appleScriptFailed(let message):
            "Could not run terminal automation: \(message)"
        }
    }
}
