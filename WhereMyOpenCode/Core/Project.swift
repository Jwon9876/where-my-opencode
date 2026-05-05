import Foundation

struct Project: Codable, Equatable, Hashable, Identifiable {
    let name: String
    let path: String
    let modifiedDate: Date

    var id: String {
        path
    }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    init(name: String, path: String, modifiedDate: Date = .distantPast) {
        self.name = name
        self.path = (path as NSString).standardizingPath
        self.modifiedDate = modifiedDate
    }

    init(url: URL, modifiedDate: Date = .distantPast) {
        let standardizedURL = url.standardizedFileURL

        self.name = standardizedURL.lastPathComponent
        self.path = standardizedURL.path
        self.modifiedDate = modifiedDate
    }
}
