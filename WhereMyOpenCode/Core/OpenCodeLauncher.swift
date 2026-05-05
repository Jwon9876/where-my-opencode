import Foundation

struct OpenCodeLauncher {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func launch(project: Project, settings: AppSettings) throws {
        try validateProjectFolder(at: project.path)
        try validateConfiguredBinary(settings.opencodePath)

        switch settings.terminalApp {
        case .appleTerminal:
            try launchInAppleTerminal(projectPath: project.path, opencodePath: settings.opencodePath)
        }
    }

    func checkConfiguration(settings: AppSettings) throws -> String {
        try validateConfiguredBinary(settings.opencodePath)

        if let opencodePath = settings.opencodePath {
            return "OpenCode binary is executable: \(opencodePath)"
        }

        return "No binary selected. Terminal will run opencode from your shell."
    }

    private func launchInAppleTerminal(projectPath: String, opencodePath: String?) throws {
        let command = "cd \(shellQuoted(projectPath)) && \(opencodeCommand(opencodePath: opencodePath))"
        let source = """
        set terminalWasRunning to application "Terminal" is running

        tell application "Terminal"
            if terminalWasRunning then
                do script \(appleScriptString(command))
            else
                launch
                repeat 20 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.05
                end repeat

                if (count of windows) > 0 then
                    do script \(appleScriptString(command)) in front window
                else
                    do script \(appleScriptString(command))
                end if
            end if

            activate
        end tell
        """

        try runAppleScript(source)
    }

    private func validateProjectFolder(at path: String) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw OpenCodeLauncherError.projectFolderMissing(path)
        }
    }

    private func validateConfiguredBinary(_ path: String?) throws {
        guard let path else {
            return
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw OpenCodeLauncherError.binaryMissing(path)
        }

        guard !isDirectory.boolValue, fileManager.isExecutableFile(atPath: path) else {
            throw OpenCodeLauncherError.binaryNotExecutable(path)
        }
    }

    private func opencodeCommand(opencodePath: String?) -> String {
        guard let opencodePath else {
            return "opencode"
        }

        return shellQuoted(opencodePath)
    }

    private func runAppleScript(_ source: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw OpenCodeLauncherError.appleScriptFailed("Could not prepare Terminal command.")
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
            throw OpenCodeLauncherError.appleScriptFailed(message ?? "Terminal did not accept the command.")
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptString(_ value: String) -> String {
        let escapedValue = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return "\"\(escapedValue)\""
    }
}

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
