import Foundation

struct OpenCodeLauncher {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func launch(project: Project, settings: AppSettings, session: TrackedSession) throws -> OpenCodeLaunchResult {
        try validateProjectFolder(at: project.path)
        try validateConfiguredBinary(settings.opencodePath)

        switch settings.terminalApp {
        case .appleTerminal:
            return try launchInAppleTerminal(
                sessionID: session.id,
                projectPath: project.path,
                opencodePath: settings.opencodePath,
                terminalTitle: session.terminalTitle
            )
        }
    }

    func checkConfiguration(settings: AppSettings) throws -> String {
        try validateConfiguredBinary(settings.opencodePath)

        if let opencodePath = settings.opencodePath {
            return "OpenCode binary is executable: \(opencodePath)"
        }

        return "No binary selected. Terminal will run opencode from your shell."
    }

    func terminalCommand(projectPath: String, opencodePath: String?) -> String {
        "cd \(shellQuoted(projectPath)) && \(opencodeCommand(opencodePath: opencodePath))"
    }

    func appleTerminalScript(command: String, terminalTitle: String) -> String {
        """
        set terminalWasRunning to application "Terminal" is running
        set launchedTab to missing value

        tell application "Terminal"
            if terminalWasRunning then
                set launchedTab to do script \(appleScriptString(command))
            else
                launch
                repeat 20 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.05
                end repeat

                if (count of windows) > 0 then
                    set launchedTab to do script \(appleScriptString(command)) in front window
                else
                    set launchedTab to do script \(appleScriptString(command))
                end if
            end if

            set launchedWindowID to ""
            set launchedTTY to ""
            set launchedCustomTitle to ""

            if launchedTab is not missing value then
                repeat 12 times
        \(appleTerminalTitleScript(tabName: "launchedTab", terminalTitle: terminalTitle))
                    delay 0.25
                end repeat

                set launchedCustomTitle to custom title of launchedTab

                try
                    set launchedTTY to tty of launchedTab
                end try

                repeat with terminalWindow in windows
                    repeat with terminalTab in tabs of terminalWindow
                        try
                            if launchedTTY is not "" and tty of terminalTab is launchedTTY then
                                set launchedWindowID to (id of terminalWindow as text)
                                exit repeat
                            end if
                        end try

                        try
                            if launchedWindowID is "" and custom title of terminalTab is launchedCustomTitle then
                                set launchedWindowID to (id of terminalWindow as text)
                                exit repeat
                            end if
                        end try
                    end repeat

                    if launchedWindowID is not "" then exit repeat
                end repeat
            end if

            activate
        end tell

        return "terminalWindowID=" & launchedWindowID & linefeed & "terminalTabTTY=" & launchedTTY & linefeed & "terminalCustomTitle=" & launchedCustomTitle
        """
    }

    private func launchInAppleTerminal(
        sessionID: String,
        projectPath: String,
        opencodePath: String?,
        terminalTitle: String
    ) throws -> OpenCodeLaunchResult {
        let command = terminalCommand(projectPath: projectPath, opencodePath: opencodePath)
        let source = appleTerminalScript(command: command, terminalTitle: terminalTitle)
        let payload = try runAppleScript(source)

        return appleTerminalLaunchResult(sessionID: sessionID, payload: payload)
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

    private func runAppleScript(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw OpenCodeLauncherError.appleScriptFailed("Could not prepare Terminal command.")
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
            throw OpenCodeLauncherError.appleScriptFailed(message ?? "Terminal did not accept the command.")
        }

        return result.stringValue ?? ""
    }

    func appleTerminalLaunchResult(
        sessionID: String,
        payload: String,
        launchedAt: Date = Date()
    ) -> OpenCodeLaunchResult {
        let values = payload
            .components(separatedBy: .newlines)
            .reduce(into: [String: String]()) { partialResult, line in
                guard let separatorIndex = line.firstIndex(of: "=") else {
                    return
                }

                let key = String(line[..<separatorIndex])
                let valueStartIndex = line.index(after: separatorIndex)
                partialResult[key] = String(line[valueStartIndex...])
            }

        return OpenCodeLaunchResult(
            sessionID: sessionID,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalTabTTY: Self.nonEmptyValue(values["terminalTabTTY"]),
            terminalCustomTitle: Self.nonEmptyValue(values["terminalCustomTitle"]),
            launchedAt: launchedAt
        )
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

    private func appleTerminalTitleScript(tabName: String, terminalTitle: String) -> String {
        """
                set custom title of \(tabName) to \(appleScriptString(terminalTitle))
                set title displays custom title of \(tabName) to true
                set title displays device name of \(tabName) to false
                set title displays shell path of \(tabName) to false
                set title displays window size of \(tabName) to false
                set title displays file name of \(tabName) to false
        """
    }

    private static func nonEmptyValue(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }
}

struct OpenCodeLaunchResult: Equatable {
    let sessionID: String
    let terminalWindowID: Int?
    let terminalTabTTY: String?
    let terminalCustomTitle: String?
    let launchedAt: Date
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
