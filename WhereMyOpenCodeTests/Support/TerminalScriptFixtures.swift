import Foundation
import XCTest

class TemporaryFileTestCase: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }

        try super.tearDownWithError()
    }

    func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhereMyOpenCodeTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }

    func writeEmptyFile(at url: URL) throws {
        try Data().write(to: url)
    }

    func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}

func occurrences(of substring: String, in source: String) -> Int {
    guard !substring.isEmpty else {
        return 0
    }

    var count = 0
    var searchRange = source.startIndex..<source.endIndex

    while let foundRange = source.range(of: substring, range: searchRange) {
        count += 1
        searchRange = foundRange.upperBound..<source.endIndex
    }

    return count
}

enum TerminalScriptFixtures {
    static let notFound = "found=false"

    static func found(records: [String]) -> String {
        (["found=true"] + records).joined(separator: "\n---\n")
    }
}
