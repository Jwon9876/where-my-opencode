import Foundation

struct ProjectScanner {
    private static let projectMarkerNames: Set<String> = [
        ".git",
        "package.json",
        "pyproject.toml",
        "Cargo.toml",
        "go.mod",
        "Makefile",
        ".opencode",
        "opencode.json"
    ]

    private static let excludedFolderNames: Set<String> = [
        ".git",
        "node_modules",
        ".next",
        "dist",
        "build",
        "target",
        ".cache",
        "vendor",
        "Pods",
        "DerivedData",
        ".swiftpm"
    ]

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(rootFolderPath: String?) throws -> [Project] {
        guard let rootFolderPath,
              !rootFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return try scan(rootFolderURL: URL(fileURLWithPath: rootFolderPath, isDirectory: true))
    }

    func scan(rootFolderURL: URL) throws -> [Project] {
        guard isDirectory(rootFolderURL) else {
            return []
        }

        let childURLs = try fileManager.contentsOfDirectory(
            at: rootFolderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        )

        return childURLs
            .filter(isScannableDirectory)
            .filter(hasProjectMarker)
            .map(makeProject)
            .sorted { lhs, rhs in
                if lhs.modifiedDate == rhs.modifiedDate {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                return lhs.modifiedDate > rhs.modifiedDate
            }
    }

    private func isScannableDirectory(_ url: URL) -> Bool {
        guard !Self.excludedFolderNames.contains(url.lastPathComponent) else {
            return false
        }

        return isDirectory(url)
    }

    private func hasProjectMarker(in folderURL: URL) -> Bool {
        Self.projectMarkerNames.contains { markerName in
            let markerURL = folderURL.appendingPathComponent(markerName)
            return fileManager.fileExists(atPath: markerURL.path)
        }
    }

    private func makeProject(from url: URL) -> Project {
        let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return Project(url: url, modifiedDate: resourceValues?.contentModificationDate ?? .distantPast)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
