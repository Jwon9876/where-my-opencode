import Foundation

struct TrackedSession: Codable, Equatable, Hashable, Identifiable, Sendable {
    static let markerPrefix = "WhereMyOpenCode"

    let id: String
    let projectName: String
    let projectPath: String
    let openedAt: Date
    let marker: String
    let terminalTitle: String
    let terminalApp: TerminalApp?
    let terminalWindowID: Int?
    let terminalSessionID: String?
    let terminalTabTTY: String?
    let terminalCustomTitle: String?
    let launchedAt: Date?

    init(
        id: String = UUID().uuidString,
        projectName: String,
        projectPath: String,
        openedAt: Date = Date(),
        terminalApp: TerminalApp? = nil,
        terminalWindowID: Int? = nil,
        terminalSessionID: String? = nil,
        terminalTabTTY: String? = nil,
        terminalCustomTitle: String? = nil,
        launchedAt: Date? = nil
    ) {
        let normalizedProjectPath = (projectPath as NSString).standardizingPath
        let safeProjectName = Self.sanitizedTitleComponent(projectName)
        let marker = "\(Self.markerPrefix):\(id)"

        self.id = id
        self.projectName = projectName
        self.projectPath = normalizedProjectPath
        self.openedAt = openedAt
        self.marker = marker
        self.terminalTitle = "\(marker) \(safeProjectName)"
        self.terminalApp = terminalApp
        self.terminalWindowID = terminalWindowID
        self.terminalSessionID = terminalSessionID
        self.terminalTabTTY = terminalTabTTY
        self.terminalCustomTitle = terminalCustomTitle
        self.launchedAt = launchedAt
    }

    init(id: String = UUID().uuidString, project: Project, openedAt: Date = Date()) {
        self.init(
            id: id,
            projectName: project.name,
            projectPath: project.path,
            openedAt: openedAt
        )
    }

    var project: Project {
        Project(name: projectName, path: projectPath)
    }

    func recordingLaunch(_ launchResult: OpenCodeLaunchResult, terminalApp: TerminalApp) -> TrackedSession {
        TrackedSession(
            id: id,
            projectName: projectName,
            projectPath: projectPath,
            openedAt: openedAt,
            terminalApp: terminalApp,
            terminalWindowID: launchResult.terminalWindowID,
            terminalSessionID: launchResult.terminalSessionID,
            terminalTabTTY: launchResult.terminalTabTTY,
            terminalCustomTitle: launchResult.terminalCustomTitle,
            launchedAt: launchResult.launchedAt
        )
    }

    private static func sanitizedTitleComponent(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
