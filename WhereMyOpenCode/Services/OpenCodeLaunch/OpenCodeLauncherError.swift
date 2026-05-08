import Foundation

enum OpenCodeLauncherError: LocalizedError {
    case projectFolderMissing(String)
    case binaryMissing(String)
    case binaryNotExecutable(String)
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .projectFolderMissing(let path):
            "Project folder does not exist: \(path)"
        case .binaryMissing(let path):
            "OpenCode binary does not exist: \(path)"
        case .binaryNotExecutable(let path):
            "OpenCode binary is not executable: \(path)"
        case .appleScriptFailed(let message):
            "Could not open Terminal: \(message)"
        }
    }
}
