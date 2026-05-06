import Foundation
import XCTest
@testable import Where_My_OpenCode

final class SessionStoreTests: TemporaryFileTestCase {
    func testSessionStorePersistsHistoryAndReturnsLatestSessionPerProject() throws {
        let rootURL = try makeTemporaryDirectory()
        let sessionsURL = rootURL.appendingPathComponent("sessions.json")
        let appPath = rootURL.appendingPathComponent("App").path
        let toolPath = rootURL.appendingPathComponent("Tool").path
        let equivalentAppPath = rootURL
            .appendingPathComponent("Nested")
            .appendingPathComponent("..")
            .appendingPathComponent("App")
            .path

        let store = SessionStore(sessionsURL: sessionsURL, maxStoredSessions: 10)
        let oldAppSession = TrackedSession(
            id: "old-app",
            projectName: "App",
            projectPath: appPath,
            openedAt: Date(timeIntervalSince1970: 100)
        )
        let toolSession = TrackedSession(
            id: "tool",
            projectName: "Tool",
            projectPath: toolPath,
            openedAt: Date(timeIntervalSince1970: 200)
        )
        let latestAppSession = TrackedSession(
            id: "latest-app",
            projectName: "App",
            projectPath: equivalentAppPath,
            openedAt: Date(timeIntervalSince1970: 300)
        )

        store.record(oldAppSession)
        store.record(toolSession)
        store.record(latestAppSession)

        XCTAssertEqual(store.recentSessions(limit: 10).map(\.id), ["latest-app", "tool"])

        let reloadedStore = SessionStore(sessionsURL: sessionsURL, maxStoredSessions: 10)
        XCTAssertEqual(reloadedStore.sessions.map(\.id), ["latest-app", "tool", "old-app"])
        XCTAssertEqual(reloadedStore.sessions(forProjectPath: appPath).map(\.id), ["latest-app", "old-app"])
    }
}
