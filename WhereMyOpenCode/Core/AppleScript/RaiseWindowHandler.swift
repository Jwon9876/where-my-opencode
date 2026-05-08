import AppKit
import ApplicationServices
import Carbon

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
                                        try
                                            set value of attribute "AXMain" of axWindow to true
                                        end try
                                        try
                                            set value of attribute "AXFocused" of axWindow to true
                                        end try
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

enum TerminalWindowRaiser {
    private static let windowLookupAttempts = 5
    private static let windowLookupRetryDelay = 0.05

    static func raise(terminalApp: TerminalApp, marker: String) {
        guard let app = runningApplication(for: terminalApp) else {
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        if !marker.isEmpty, let window = matchingWindow(in: appElement, marker: marker) {
            focusAndActivate(window, processID: app.processIdentifier)
            return
        }

        for attempt in 0..<windowLookupAttempts {
            if !marker.isEmpty, let window = matchingWindow(in: appElement, marker: marker) {
                focusAndActivate(window, processID: app.processIdentifier)
                return
            }

            if attempt < windowLookupAttempts - 1 {
                Thread.sleep(forTimeInterval: windowLookupRetryDelay)
            }
        }

        if let selectedWindow = selectedWindow(in: appElement) {
            focusAndActivate(selectedWindow, processID: app.processIdentifier)
            return
        }

        activateFrontWindowOnly(processID: app.processIdentifier)
    }

    private static func runningApplication(for terminalApp: TerminalApp) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            app.bundleIdentifier == terminalApp.bundleIdentifier
        }
    }

    private static func matchingWindow(in appElement: AXUIElement, marker: String) -> AXUIElement? {
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return nil
        }

        return windows.first { window in
            title(of: window).contains(marker)
        }
    }

    private static func title(of window: AXUIElement) -> String {
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String else {
            return ""
        }

        return title
    }

    private static func makeMainAndRaise(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private static func focusAndActivate(_ window: AXUIElement, processID: pid_t) {
        makeMainAndRaise(window)
        activateFrontWindowOnly(processID: processID)
        makeMainAndRaise(window)
    }

    private static func selectedWindow(in appElement: AXUIElement) -> AXUIElement? {
        if let focusedWindow = attributeWindow(appElement, attribute: kAXFocusedWindowAttribute) {
            return focusedWindow
        }

        if let mainWindow = attributeWindow(appElement, attribute: kAXMainWindowAttribute) {
            return mainWindow
        }

        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return nil
        }

        return windows.first
    }

    private static func attributeWindow(_ appElement: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, attribute as CFString, &value) == .success,
              let rawValue = value,
              CFGetTypeID(rawValue) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(rawValue, to: AXUIElement.self)
    }

    private static func activateFrontWindowOnly(processID: pid_t) {
        var processSerialNumber = ProcessSerialNumber()
        guard WMOCGetProcessForPID(processID, &processSerialNumber) == noErr else {
            return
        }

        _ = WMOCSetFrontProcessWithOptions(&processSerialNumber, OptionBits(kSetFrontProcessFrontWindowOnly))
    }
}

// Swift marks these Carbon process APIs unavailable, but the symbols remain
// available and provide the single-front-window activation behavior we need.
@_silgen_name("GetProcessForPID")
private func WMOCGetProcessForPID(
    _ processID: pid_t,
    _ processSerialNumber: UnsafeMutablePointer<ProcessSerialNumber>
) -> OSStatus

@_silgen_name("SetFrontProcessWithOptions")
private func WMOCSetFrontProcessWithOptions(
    _ processSerialNumber: UnsafePointer<ProcessSerialNumber>,
    _ options: OptionBits
) -> OSStatus

private extension TerminalApp {
    var bundleIdentifier: String {
        switch self {
        case .appleTerminal:
            "com.apple.Terminal"
        case .iTerm2:
            "com.googlecode.iterm2"
        }
    }
}
