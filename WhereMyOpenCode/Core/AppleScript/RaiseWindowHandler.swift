enum RaiseWindowHandler {
    static let source: String = """

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
}
