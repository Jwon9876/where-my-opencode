struct AppleTerminalLauncher {
    typealias ScriptRunner = (String) throws -> String
    typealias WindowRaiser = (TerminalApp, String) -> Void

    private let runAppleScript: ScriptRunner
    private let raiseWindow: WindowRaiser

    init(
        runAppleScript: @escaping ScriptRunner = AppleScriptRunner(
            preparationFailureMessage: "Could not prepare Terminal command.",
            executionFailureFallbackMessage: "Terminal did not accept the command.",
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
            raiseWindow(.appleTerminal, marker)
        }
    }
}
