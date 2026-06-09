import XCTest
@testable import ZapApp

final class SettingsWindowManagementUITests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testSettingsModeIncludesAutomaticManualAndWindowManagement() {
        XCTAssertEqual(SettingsMode.allCases.map(\.title), [
            "Automatic",
            "Manual",
            "Window Management"
        ])
    }

    func testSettingsViewRoutesWindowManagementModeAndKeepsExistingModes() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("case automatic"))
        XCTAssertTrue(source.contains("case manual"))
        XCTAssertTrue(source.contains("case windowManagement"))
        XCTAssertTrue(source.contains("Window Management"))
        XCTAssertTrue(source.contains("WindowManagementSettingsView"))
    }

    func testSettingsStillContainsBehaviorAndSparkleUpdateControls() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("Section(\"Behavior\")"))
        XCTAssertTrue(source.contains("Launch at login"))
        XCTAssertTrue(source.contains("Show menu bar icon"))
        XCTAssertTrue(source.contains("Section(\"Updates\")"))
        XCTAssertTrue(source.contains("Automatically check for updates"))
        XCTAssertTrue(source.contains("Check for Updates Now"))
        XCTAssertTrue(source.contains("Updates are delivered with Sparkle"))
    }

    func testAutomaticAndManualShortcutControlsRemainWired() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("automaticShortcutsSection"))
        XCTAssertTrue(source.contains("Finder shortcut"))
        XCTAssertTrue(source.contains("Dock app shortcuts"))
        XCTAssertTrue(source.contains("manualSection"))
        XCTAssertTrue(source.contains("ManualShortcutRow"))
        XCTAssertTrue(source.contains("Add App Shortcut"))
    }

    func testWindowManagementSettingsViewContainsPermissionEnableResetAndShortcutRows() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(source.contains("Accessibility Permission"))
        XCTAssertTrue(source.contains("Open Accessibility Settings"))
        XCTAssertTrue(source.contains("Refresh Permission"))
        XCTAssertTrue(source.contains("Request Permission"))
        XCTAssertTrue(source.contains("Enable window management shortcuts"))
        XCTAssertTrue(source.contains("Reset to Defaults"))
        XCTAssertTrue(source.contains("WindowShortcutRowView"))
        XCTAssertTrue(source.contains("ForEach(model.windowShortcuts"))
    }

    func testWindowManagementSettingsReceivesAndDisplaysGlobalRegistrationError() throws {
        let settingsSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))
        let windowManagementSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(settingsSource.contains("WindowManagementSettingsView(model: model.windowManagementModel, registrationError: model.registrationError)"))
        XCTAssertTrue(windowManagementSource.contains("let registrationError: String?"))
        XCTAssertTrue(windowManagementSource.contains("if let registrationError"))
        XCTAssertTrue(windowManagementSource.contains("Text(registrationError)"))
    }
}
