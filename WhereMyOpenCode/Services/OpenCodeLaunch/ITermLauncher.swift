struct ITermLauncher {
    typealias ScriptRunner = (String) throws -> String
    typealias WindowRaiser = (TerminalApp, String) -> Void

    private let runAppleScript: ScriptRunner
    private let raiseWindow: WindowRaiser

    init(
        runAppleScript: @escaping ScriptRunner = AppleScriptRunner(
            preparationFailureMessage: "Could not prepare iTerm2 command.",
            executionFailureFallbackMessage: "iTerm2 did not accept the command.",
            makeError: { OpenCodeLauncherError.appleScriptFailed($0) }
        ).run,
        raiseWindow: @escaping WindowRaiser = TerminalWindowRaiser.raise
    ) {
        self.runAppleScript = runAppleScript
        self.raiseWindow = raiseWindow
    }

    func launch(
        sessionID: String,
        command: String,
        terminalTitle: String,
        marker: String,
        focusPolicy: OpenCodeLaunchFocusPolicy
    ) throws -> OpenCodeLaunchResult {
        let payload = try runAppleScript(
            script(
                command: command,
                terminalTitle: terminalTitle,
                marker: marker,
                focusPolicy: focusPolicy
            )
        )

        let result = OpenCodeLaunchResult.parse(sessionID: sessionID, payload: payload)
        raiseLaunchedWindowIfNeeded(marker: marker, focusPolicy: focusPolicy)

        return result
    }

    func script(
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

    private func appleScriptString(_ value: String) -> String {
        AppleScriptSupport.stringLiteral(value)
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
            RaiseWindowHandler.source
        }
    }

    private func raiseLaunchedWindowIfNeeded(marker: String, focusPolicy: OpenCodeLaunchFocusPolicy) {
        switch focusPolicy {
        case .none:
            break
        case .raiseLaunchedWindow:
            raiseWindow(.iTerm2, marker)
        }
    }
}
