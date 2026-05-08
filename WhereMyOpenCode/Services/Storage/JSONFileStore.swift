import Foundation

struct JSONFileStore<Value: Codable> {
    let url: URL

    private let fileManager: FileManager

    init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    func load() throws -> Value {
        guard fileManager.fileExists(atPath: url.path) else {
            throw JSONFileStoreError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}

enum JSONFileStoreError: Error {
    case fileNotFound
}
