import XCTest

final class SettingsShortcutControlsUITests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var settingsSource: String {
        get throws {
            try String(contentsOf: packageRootURL
                .appendingPathComponent(
                    "Sources/ZapApp/Views/SettingsView.swift"
                ))
        }
    }

    func testGeneralPlacesShortcutControlsBetweenPermissionsAndBehavior()
        throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "            permissionsSection\n            shortcutControlsSection\n            behaviorSection"
        ))
        XCTAssertTrue(source.contains(
            "SettingsCard(title: \"Shortcut Controls\")"
        ))
    }

    func testShortcutControlsRendersRequiredCopyAndKeycap() throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "Toggle Zap for Current App"
        ))
        XCTAssertTrue(source.contains(
            "Disable or re-enable Zap shortcuts for the currently active app."
        ))
        XCTAssertTrue(source.contains(
            "ShortcutKeycapGroupView(shortcut: model.activeApplicationToggleShortcut.shortcutTitle)"
        ))
    }

    func testShortcutControlsOpensRecorderAndAppliesRecording()
        throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "isRecordingActiveApplicationToggleShortcut = true"
        ))
        XCTAssertTrue(source.contains(
            "ShortcutRecorderView("
        ))
        XCTAssertTrue(source.contains(
            "activeApplicationToggleOnRecord:"
        ))
        XCTAssertTrue(source.contains(
            "model.setActiveApplicationToggleShortcut("
        ))
    }

    func testConfiguredShortcutExposesClearAction() throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "model.activeApplicationToggleShortcut.canRegister"
        ))
        XCTAssertTrue(source.contains(
            "Button(\"Clear\", role: .destructive)"
        ))
        XCTAssertTrue(source.contains(
            "model.clearActiveApplicationToggleShortcut()"
        ))
    }

    func testShortcutControlsDisplaysGlobalRegistrationError()
        throws {
        let source = try settingsSource
        let sectionStart = try XCTUnwrap(source.range(
            of: "    private var shortcutControlsSection: some View {"
        ))
        let sectionEnd = try XCTUnwrap(source.range(
            of: "    private var automaticShortcutsSection: some View {",
            range: sectionStart.upperBound..<source.endIndex
        ))
        let sectionSource = String(source[sectionStart.lowerBound..<sectionEnd.lowerBound])

        XCTAssertTrue(sectionSource.contains(
            "if let registrationError = model.registrationError"
        ))
        XCTAssertTrue(sectionSource.contains(
            "Label(registrationError, systemImage: \"exclamationmark.triangle.fill\")"
        ))
    }
}
