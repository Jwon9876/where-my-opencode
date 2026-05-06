import Foundation
import XCTest
@testable import Where_My_OpenCode

final class SettingsStoreTests: TemporaryFileTestCase {
func testSettingsStorePersistsNormalizedPathsAndTerminalApp() throws {
    let rootURL = try makeTemporaryDirectory()
    let settingsURL = rootURL.appendingPathComponent("settings.json")
    let rawRootPath = rootURL
        .appendingPathComponent("Workspace")
        .appendingPathComponent("..")
        .appendingPathComponent("Projects")
        .path
    let rawBinaryPath = rootURL
        .appendingPathComponent("bin")
        .appendingPathComponent("..")
        .appendingPathComponent("opencode")
        .path

    let store = SettingsStore(settingsURL: settingsURL)
    store.setRootFolderPath(rawRootPath)
    store.setOpenCodePath(rawBinaryPath)
    store.setTerminalApp(.iTerm2)

    let reloadedStore = SettingsStore(settingsURL: settingsURL)

    XCTAssertEqual(reloadedStore.settings.rootFolderPath, (rawRootPath as NSString).standardizingPath)
    XCTAssertEqual(reloadedStore.settings.opencodePath, (rawBinaryPath as NSString).standardizingPath)
    XCTAssertEqual(reloadedStore.settings.terminalApp, .iTerm2)
    XCTAssertNil(reloadedStore.lastErrorMessage)
}
}
