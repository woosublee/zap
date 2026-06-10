import XCTest

final class MenuBarViewTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testMenuBarGroupsStatusQuickLaunchWindowManagementMaintenanceAndAppActions() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

        XCTAssertTrue(source.contains("sectionLabel(\"Status\")"))
        XCTAssertTrue(source.contains("sectionLabel(\"Quick Launch\")"))
        XCTAssertTrue(source.contains("sectionLabel(\"Window Management\")"))
        XCTAssertTrue(source.contains("sectionLabel(\"Maintenance\")"))
        XCTAssertTrue(source.contains("sectionLabel(\"App\")"))
        XCTAssertTrue(source.contains("Finder"))
        XCTAssertTrue(source.contains("activeManualShortcuts"))
        XCTAssertTrue(source.contains("Refresh Dock Apps"))
        XCTAssertTrue(source.contains("Settings..."))
        XCTAssertTrue(source.contains("Check for Updates..."))
        XCTAssertTrue(source.contains("Quit"))
    }

    func testMenuBarDoesNotListEveryWindowActionShortcut() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

        XCTAssertTrue(source.contains("Window Shortcuts..."))
        XCTAssertTrue(source.contains("openWindowManagementSettings"))
        XCTAssertFalse(source.contains("ForEach(model.windowManagementModel.windowShortcuts"))
        XCTAssertFalse(source.contains("ForEach(model.windowShortcuts"))
    }

    func testMenuBarHidesEmptyDockSlotsInsteadOfListingAllNineSlots() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

        XCTAssertTrue(source.contains("if let item = model.dockItem(for: key)"))
        XCTAssertFalse(source.contains("Dock slot \\(key.rawValue)"))
        XCTAssertFalse(source.contains("disabled: item == nil"))
    }

    func testMenuBarStatusSummarizesAccessibilityAndErrors() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

        XCTAssertTrue(source.contains("model.windowManagementModel.accessibilityTrusted"))
        XCTAssertTrue(source.contains("Accessibility"))
        XCTAssertTrue(source.contains("Ready"))
        XCTAssertTrue(source.contains("Needs Permission"))
        XCTAssertTrue(source.contains("registrationError"))
        XCTAssertTrue(source.contains("windowManagementError"))
    }

    func testMenuBarUsesSharedKeycapsAndBrandedHeader() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

        XCTAssertTrue(source.contains("ShortcutKeycapGroupView"))
        XCTAssertTrue(source.contains("NSApp.applicationIconImage"))
        XCTAssertTrue(source.contains("Quick Launch"))
        XCTAssertTrue(source.contains("Maintenance"))
        XCTAssertTrue(source.contains("sectionLabel(\"App\")"))
    }
}
