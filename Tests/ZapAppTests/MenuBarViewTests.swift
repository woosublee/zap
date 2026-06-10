import XCTest

final class MenuBarViewTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var menuBarSource: String {
        get throws {
            try String(contentsOf: packageRootURL
                .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))
        }
    }

    private var appSource: String {
        get throws {
            try String(contentsOf: packageRootURL
                .appendingPathComponent("Sources/ZapApp/ZapApp.swift"))
        }
    }

    func testMenuBarUsesNativeQuickLaunchAndWindowControlSubmenus() throws {
        let source = try menuBarSource

        XCTAssertTrue(source.contains("Menu(\"Quick Launch\")"))
        XCTAssertTrue(source.contains("Menu(\"Window Control\")"))
        XCTAssertTrue(source.contains("Button(\"Refresh Dock Apps\")"))
        XCTAssertTrue(source.contains("Button(\"Check for Updates...\")"))
        XCTAssertTrue(source.contains("Button(\"Settings...\")"))
        XCTAssertTrue(source.contains("Button(\"Quit \\(AboutPresentation.currentAppName)\")"))
    }

    func testMenuBarQuickLaunchSubmenuKeepsFinderManualAndDockActions() throws {
        let source = try menuBarSource

        XCTAssertTrue(source.contains("model.isFinderShortcutEnabled"))
        XCTAssertTrue(source.contains("model.activateFinder()"))
        XCTAssertTrue(source.contains("model.activeManualShortcuts"))
        XCTAssertTrue(source.contains("model.activateManualShortcut(id: shortcut.id)"))
        XCTAssertTrue(source.contains("NumberKey.allCases"))
        XCTAssertTrue(source.contains("if let item = model.dockItem(for: key)"))
        XCTAssertTrue(source.contains("model.activateDockItem(for: key)"))
        XCTAssertFalse(source.contains("Dock slot \\(key.rawValue)"))
    }

    func testMenuBarWindowControlSubmenuListsConfiguredWindowShortcuts() throws {
        let source = try menuBarSource

        XCTAssertTrue(source.contains("WindowActionCategory.allCases"))
        XCTAssertTrue(source.contains("model.windowManagementModel.windowShortcuts"))
        XCTAssertTrue(source.contains("WindowShortcutDisplay.shortcutTitle(for: shortcut)"))
        XCTAssertTrue(source.contains("model.windowManagementModel.perform(action: shortcut.action)"))
        XCTAssertTrue(source.contains("Divider()"))
        XCTAssertFalse(source.contains("Window Shortcuts..."))
        XCTAssertFalse(source.contains("openWindowManagementSettings"))
    }

    func testMenuBarRemovesStatusAndAboutRows() throws {
        let source = try menuBarSource

        XCTAssertFalse(source.contains("sectionLabel(\"Status\")"))
        XCTAssertFalse(source.contains("StatusRow"))
        XCTAssertFalse(source.contains("Accessibility"))
        XCTAssertFalse(source.contains("Needs Permission"))
        XCTAssertFalse(source.contains("Ready"))
        XCTAssertFalse(source.contains("registrationError"))
        XCTAssertFalse(source.contains("windowManagementError"))
        XCTAssertFalse(source.contains("AboutPresentation.aboutMenuLabel"))
        XCTAssertFalse(source.contains("openAbout"))
    }

    func testMenuBarNoLongerUsesCustomWindowPanelRows() throws {
        let source = try menuBarSource

        XCTAssertFalse(source.contains("private var header"))
        XCTAssertFalse(source.contains("private struct MenuRow"))
        XCTAssertFalse(source.contains("ShortcutKeycapGroupView"))
        XCTAssertFalse(source.contains("NSApp.applicationIconImage"))
        XCTAssertFalse(source.contains("frame(width: 340)"))
    }

    func testZapAppUsesMenuStyleMenuBarExtra() throws {
        let source = try appSource

        XCTAssertTrue(source.contains(".menuBarExtraStyle(.menu)"))
        XCTAssertFalse(source.contains(".menuBarExtraStyle(.window)"))
        XCTAssertFalse(source.contains("openWindowManagementSettings:"))
        XCTAssertFalse(source.contains("openAbout:"))
        XCTAssertFalse(source.contains("private func openAbout()"))
    }
}
