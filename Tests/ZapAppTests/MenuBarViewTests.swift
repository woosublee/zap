import XCTest

final class MenuBarViewTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testMenuBarKeepsDockFinderManualRowsAndSettingsUpdateActions() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

        XCTAssertTrue(source.contains("Finder"))
        XCTAssertTrue(source.contains("activeManualShortcuts"))
        XCTAssertTrue(source.contains("NumberKey.allCases"))
        XCTAssertTrue(source.contains("Refresh Dock Apps"))
        XCTAssertTrue(source.contains("Settings..."))
        XCTAssertTrue(source.contains("Check for Updates..."))
        XCTAssertTrue(source.contains("Quit"))
    }

    func testMenuBarDoesNotListEveryWindowActionShortcut() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

        XCTAssertFalse(source.contains("ForEach(model.windowManagementModel.windowShortcuts"))
        XCTAssertFalse(source.contains("ForEach(model.windowShortcuts"))
    }
}
