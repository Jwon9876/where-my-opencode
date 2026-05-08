import Foundation

enum AppSupportPaths {
    private static let directoryName = "where-my-opencode"

    static func file(named fileName: String, fileManager: FileManager = .default) -> URL {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
