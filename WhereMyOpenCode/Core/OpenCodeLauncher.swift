import Foundation

enum OpenCodeLaunchFocusPolicy: Sendable {
    case none
    case raiseLaunchedWindow
}

struct OpenCodeLauncher {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func launch(
        project: Project,
        settings: AppSettings,
        session: TrackedSession,
        focusPolicy: OpenCodeLaunchFocusPolicy = .raiseLaunchedWindow
    ) throws -> OpenCodeLaunchResult {
        try validateProjectFolder(at: project.path)
        try validateConfiguredBinary(settings.opencodePath)

        switch settings.terminalApp {
        case .appleTerminal:
            return try launchInAppleTerminal(
                sessionID: session.id,
                projectPath: project.path,
                opencodePath: settings.opencodePath,
                terminalTitle: session.terminalTitle,
                marker: session.marker,
                focusPolicy: focusPolicy
            )
        case .iTerm2:
            return try launchInITerm2(
                sessionID: session.id,
                projectPath: project.path,
                opencodePath: settings.opencodePath,
                terminalTitle: session.terminalTitle,
                marker: session.marker,
                focusPolicy: focusPolicy
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

    func appleTerminalScript(
        command: String,
        terminalTitle: String,
        marker: String = "",
        focusPolicy: OpenCodeLaunchFocusPolicy = .raiseLaunchedWindow
    ) -> String {
        """
        set terminalWasRunning to application "Terminal" is running
        set launchedWindow to missing value
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
        \(appleTerminalTitleScript(tabName: "launchedTab", terminalTitle: terminalTitle))

                repeat 6 times
                    try
                        set launchedTTY to tty of launchedTab
                    end try

                    if launchedTTY is not "" then exit repeat
                    delay 0.05
                end repeat

                try
                    set launchedCustomTitle to custom title of launchedTab
                end try

                repeat with terminalWindow in windows
                    repeat with terminalTab in tabs of terminalWindow
                        try
                            if launchedTTY is not "" and tty of terminalTab is launchedTTY then
                                set launchedWindowID to (id of terminalWindow as text)
                                set launchedWindow to terminalWindow
                                exit repeat
                            end if
                        end try

                        try
                            if launchedWindowID is "" and custom title of terminalTab is launchedCustomTitle then
                                set launchedWindowID to (id of terminalWindow as text)
                                set launchedWindow to terminalWindow
                                exit repeat
                            end if
                        end try
                    end repeat

                    if launchedWindowID is not "" then exit repeat
                end repeat
            end if
        \(appleTerminalLaunchFocusScript(marker: marker, focusPolicy: focusPolicy))
        end tell

        return "terminalWindowID=" & launchedWindowID & linefeed & "terminalTabTTY=" & launchedTTY & linefeed & "terminalCustomTitle=" & launchedCustomTitle
        \(raiseWindowMatchingHandlerScript(focusPolicy: focusPolicy))
        """
    }

    func iTerm2Script(
        command: String,
        terminalTitle: String,
        marker: String = "",
        focusPolicy: OpenCodeLaunchFocusPolicy = .raiseLaunchedWindow
    ) -> String {
        """
        set iTermWasRunning to application id "com.googlecode.iterm2" is running
        set launchedWindow to missing value
        set launchedTab to missing value
        set launchedSession to missing value

        tell application id "com.googlecode.iterm2"
            if iTermWasRunning then
                set launchedWindow to create window with default profile
                set launchedTab to current tab of launchedWindow
            else
                launch

                repeat 20 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.05
                end repeat

                if (count of windows) > 0 then
                    set launchedWindow to current window
                    set launchedTab to current tab of launchedWindow
                else
                    set launchedWindow to create window with default profile
                    set launchedTab to current tab of launchedWindow
                end if
            end if

            set launchedSession to current session of launchedTab
            set launchedWindowID to ""
            set launchedSessionID to ""
            set launchedTTY to ""
            set launchedName to ""

            if launchedSession is not missing value then
                try
                    set name of launchedSession to \(appleScriptString(terminalTitle))
                end try

                try
                    set launchedWindowID to (id of launchedWindow as text)
                end try

                try
                    set launchedSessionID to unique id of launchedSession
                end try

                repeat 6 times
                    try
                        set launchedTTY to tty of launchedSession
                    end try

                    if launchedTTY is not "" then exit repeat
                    delay 0.05
                end repeat

                try
                    set launchedName to name of launchedSession
                end try

        \(iTermLaunchFocusScript(marker: marker, focusPolicy: focusPolicy))
                tell launchedSession to write text \(appleScriptString(command))
            end if
        end tell

        return "terminalWindowID=" & launchedWindowID & linefeed & "terminalSessionID=" & launchedSessionID & linefeed & "terminalTabTTY=" & launchedTTY & linefeed & "terminalCustomTitle=" & launchedName
        \(raiseWindowMatchingHandlerScript(focusPolicy: focusPolicy))
        """
    }

    private func launchInAppleTerminal(
        sessionID: String,
        projectPath: String,
        opencodePath: String?,
        terminalTitle: String,
        marker: String,
        focusPolicy: OpenCodeLaunchFocusPolicy
    ) throws -> OpenCodeLaunchResult {
        let command = terminalCommand(projectPath: projectPath, opencodePath: opencodePath)
        let source = appleTerminalScript(
            command: command,
            terminalTitle: terminalTitle,
            marker: marker,
            focusPolicy: focusPolicy
        )
        let payload = try runAppleScript(source)

        return appleTerminalLaunchResult(sessionID: sessionID, payload: payload)
    }

    private func launchInITerm2(
        sessionID: String,
        projectPath: String,
        opencodePath: String?,
        terminalTitle: String,
        marker: String,
        focusPolicy: OpenCodeLaunchFocusPolicy
    ) throws -> OpenCodeLaunchResult {
        let command = terminalCommand(projectPath: projectPath, opencodePath: opencodePath)
        let source = iTerm2Script(
            command: command,
            terminalTitle: terminalTitle,
            marker: marker,
            focusPolicy: focusPolicy
        )
        let payload = try runAppleScript(source)

        return terminalLaunchResult(sessionID: sessionID, payload: payload)
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
        terminalLaunchResult(sessionID: sessionID, payload: payload, launchedAt: launchedAt)
    }

    func terminalLaunchResult(
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
            terminalSessionID: Self.nonEmptyValue(values["terminalSessionID"]),
            terminalTabTTY: Self.nonEmptyValue(values["terminalTabTTY"]),
            terminalCustomTitle: Self.nonEmptyValue(values["terminalCustomTitle"]),
            launchedAt: launchedAt
        )
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptString(_ value: String) -> String {
        AppleScriptSupport.stringLiteral(value)
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

    private func appleTerminalLaunchFocusScript(
        marker: String,
        focusPolicy: OpenCodeLaunchFocusPolicy
    ) -> String {
        switch focusPolicy {
        case .none:
            ""
        case .raiseLaunchedWindow:
            """

            if launchedTab is not missing value then
                if launchedWindow is not missing value then
                    set selected tab of launchedWindow to launchedTab
                    set index of launchedWindow to 1
                    my raiseWindowMatching("Terminal", \(appleScriptString(marker)))
                end if
            end if
            """
        }
    }

    private func iTermLaunchFocusScript(
        marker: String,
        focusPolicy: OpenCodeLaunchFocusPolicy
    ) -> String {
        switch focusPolicy {
        case .none:
            ""
        case .raiseLaunchedWindow:
            """
                select launchedSession
                select launchedTab
                select launchedWindow
                my raiseWindowMatching("iTerm2", \(appleScriptString(marker)))
            """
        }
    }

    private func raiseWindowMatchingHandlerScript(focusPolicy: OpenCodeLaunchFocusPolicy) -> String {
        switch focusPolicy {
        case .none:
            ""
        case .raiseLaunchedWindow:
            OpenCodeLauncher.raiseWindowMatchingHandlerSource
        }
    }

    static let raiseWindowMatchingHandlerSource: String = """

    on raiseWindowMatching(processName, identifier)
        if identifier is "" then return
        try
            tell application "System Events"
                if exists process processName then
                    tell process processName
                        repeat 5 times
                            repeat with axWindow in windows
                                try
                                    set windowTitle to title of axWindow
                                    if windowTitle contains identifier then
                                        perform action "AXRaise" of axWindow
                                        return
                                    end if
                                end try
                            end repeat
                            delay 0.05
                        end repeat
                    end tell
                end if
            end tell
        end try
    end raiseWindowMatching
    """

    private static func nonEmptyValue(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }
}

struct OpenCodeLaunchResult: Equatable, Sendable {
    let sessionID: String
    let terminalWindowID: Int?
    let terminalSessionID: String?
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
