enum MenuBarRowActionPolicy {
    static let showOrOpenHelpText = "Show existing session or open OpenCode"
    static let openNewSessionHelpText = "Open new OpenCode session"
    static let focusLiveSessionHelpText = "Show existing OpenCode session"

    static func showingExistingMessage(projectName: String) -> String {
        "Showing existing \(projectName) OpenCode session."
    }

    static func openingNewSessionMessage(projectName: String) -> String {
        "Opening new \(projectName) OpenCode session."
    }

    static func newSessionProject(for trackedSession: TrackedSession?) -> Project? {
        trackedSession?.project
    }
}
