import Combine
import Foundation

final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [TrackedSession]
    @Published private(set) var lastErrorMessage: String?

    let sessionsURL: URL

    private let maxStoredSessions: Int

    init(
        sessionsURL: URL = SessionStore.defaultSessionsURL(),
        maxStoredSessions: Int = 100
    ) {
        self.sessionsURL = sessionsURL
        self.maxStoredSessions = maxStoredSessions

        do {
            sessions = try Self.loadSessions(from: sessionsURL)
            lastErrorMessage = nil
        } catch SessionStoreError.fileNotFound {
            sessions = []
            lastErrorMessage = nil
        } catch {
            sessions = []
            lastErrorMessage = "Could not load session history."
        }

        sortAndTrimSessions()
    }

    func record(_ session: TrackedSession) {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        sortAndTrimSessions()
        saveSessions()
    }

    func recentSessions(limit: Int = 5) -> [TrackedSession] {
        var seenProjectPaths = Set<String>()
        var recentSessions: [TrackedSession] = []

        for session in sessions.sorted(by: Self.sortMostRecentFirst) {
            guard !seenProjectPaths.contains(session.projectPath) else {
                continue
            }

            seenProjectPaths.insert(session.projectPath)
            recentSessions.append(session)

            if recentSessions.count == limit {
                break
            }
        }

        return recentSessions
    }

    func sessions(forProjectPath projectPath: String) -> [TrackedSession] {
        let normalizedProjectPath = (projectPath as NSString).standardizingPath

        return sessions
            .filter { $0.projectPath == normalizedProjectPath }
            .sorted(by: Self.sortMostRecentFirst)
    }

    private func sortAndTrimSessions() {
        sessions.sort(by: Self.sortMostRecentFirst)

        if sessions.count > maxStoredSessions {
            sessions = Array(sessions.prefix(maxStoredSessions))
        }
    }

    private func saveSessions() {
        do {
            try FileManager.default.createDirectory(
                at: sessionsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sessions)
            try data.write(to: sessionsURL, options: .atomic)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not save session history."
        }
    }

    private static func loadSessions(from url: URL) throws -> [TrackedSession] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SessionStoreError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TrackedSession].self, from: data)
    }

    private static func defaultSessionsURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("where-my-opencode", isDirectory: true)
            .appendingPathComponent("sessions.json")
    }

    private static func sortMostRecentFirst(lhs: TrackedSession, rhs: TrackedSession) -> Bool {
        if lhs.openedAt == rhs.openedAt {
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        return lhs.openedAt > rhs.openedAt
    }
}

private enum SessionStoreError: Error {
    case fileNotFound
}
