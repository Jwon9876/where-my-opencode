import Foundation
import XCTest
@testable import Where_My_OpenCode

final class ProjectScannerTests: TemporaryFileTestCase {
    func testProjectScannerFindsMarkedDirectChildrenAndSkipsExcludedFolders() throws {
        let rootURL = try makeTemporaryDirectory()
        let olderProjectURL = rootURL.appendingPathComponent("OlderApp", isDirectory: true)
        let recentProjectURL = rootURL.appendingPathComponent("RecentApp", isDirectory: true)
        let excludedProjectURL = rootURL.appendingPathComponent("node_modules", isDirectory: true)

        try FileManager.default.createDirectory(at: olderProjectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: recentProjectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: excludedProjectURL, withIntermediateDirectories: true)

        try writeEmptyFile(at: olderProjectURL.appendingPathComponent("package.json"))
        try writeEmptyFile(at: recentProjectURL.appendingPathComponent("Cargo.toml"))
        try writeEmptyFile(at: excludedProjectURL.appendingPathComponent("package.json"))

        try setModificationDate(Date(timeIntervalSince1970: 100), for: olderProjectURL)
        try setModificationDate(Date(timeIntervalSince1970: 200), for: recentProjectURL)

        let projects = try ProjectScanner().scan(rootFolderURL: rootURL)

        XCTAssertEqual(projects.map(\.name), ["RecentApp", "OlderApp"])
        XCTAssertFalse(projects.map(\.name).contains("node_modules"))
    }
}
