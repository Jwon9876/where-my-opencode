import Foundation

enum OpenCodeLaunchFocusPolicy: Sendable {
    case none
    case raiseLaunchedWindow
}

struct OpenCodeLauncher {
    private let fileManager: FileManager
    private let appleTerminalLauncher: AppleTerminalLauncher
    private let iTermLauncher: ITermLauncher

    init(
        fileManager: FileManager = .default,
        appleTerminalLauncher: AppleTerminalLauncher = AppleTerminalLauncher(),
        iTermLauncher: ITermLauncher = ITermLauncher()
    ) {
        self.fileManager = fileManager
        self.appleTerminalLauncher = appleTerminalLauncher
        self.iTermLauncher = iTermLauncher
    }

    func launch(
        project: Project,
        settings: AppSettings,
        session: TrackedSession,
        focusPolicy: OpenCodeLaunchFocusPolicy = .raiseLaunchedWindow
    ) throws -> OpenCodeLaunchResult {
        try validateProjectFolder(at: project.path)
        try validateConfiguredBinary(settings.opencodePath)

        let command = terminalCommand(projectPath: project.path, opencodePath: settings.opencodePath)

        switch settings.terminalApp {
        case .appleTerminal:
            return try appleTerminalLauncher.launch(
                sessionID: session.id,
                command: command,
                terminalTitle: session.terminalTitle,
                marker: session.marker,
                focusPolicy: focusPolicy
            )
        case .iTerm2:
            return try iTermLauncher.launch(
                sessionID: session.id,
                command: command,
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

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
