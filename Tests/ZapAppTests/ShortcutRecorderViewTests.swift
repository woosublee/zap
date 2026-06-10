import XCTest

final class ShortcutRecorderViewTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testShortcutRecorderSupportsAppAndWindowActionCopy() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ShortcutRecorderView.swift"))

        XCTAssertTrue(source.contains("Record App Shortcut"))
        XCTAssertTrue(source.contains("Record Window Shortcut"))
        XCTAssertTrue(source.contains("Press the global shortcut that opens"))
        XCTAssertTrue(source.contains("Press the global shortcut that runs"))
        XCTAssertTrue(source.contains("Select at least one modifier key."))
        XCTAssertTrue(source.contains("guard !modifiers.isEmpty else"))
    }

    func testWindowShortcutRecorderReportsRecordingLifecycle() throws {
        let rowSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))
        let settingsSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(rowSource.contains("let setRecordingActive: (Bool) -> Void"))
        XCTAssertTrue(rowSource.contains("setRecordingActive(true)"))
        XCTAssertTrue(rowSource.contains("setRecordingActive(false)"))
        XCTAssertTrue(settingsSource.contains("model.setShortcutRecordingActive(isRecording)"))
    }

    func testShortcutRecorderUsesGenericModifierPrompt() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ShortcutRecorderView.swift"))

        XCTAssertTrue(source.contains("ShortcutKeycapView(label: \"Modifier\""))
        XCTAssertTrue(source.contains("ShortcutKeycapView(label: capturePrompt"))
        XCTAssertTrue(source.contains("Press any modifier key plus a key. Esc cancels."))
        XCTAssertFalse(source.contains("ShortcutKeycapView(label: \"⌘\""))
        XCTAssertFalse(source.contains("ShortcutKeycapView(label: \"⌥\""))
        XCTAssertTrue(source.contains("recordingPulse"))
    }

    func testShortcutRecorderCapturesControlKeyBindingsBeforeAppKitConsumesThem() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ShortcutRecorderView.swift"))

        XCTAssertTrue(source.contains("NSEvent.addLocalMonitorForEvents(matching: .keyDown)"))
        XCTAssertTrue(source.contains("guard let window = self.window,"))
        XCTAssertTrue(source.contains("window.isKeyWindow,"))
        XCTAssertTrue(source.contains("event.window === window else"))
        XCTAssertFalse(source.contains("guard self.window != nil else { return event }"))
        XCTAssertTrue(source.contains("onKeyDown(event)"))
        XCTAssertTrue(source.contains("return nil"))
        XCTAssertTrue(source.contains("NSEvent.removeMonitor(monitor)"))
    }

    func testWindowShortcutRowUsesKeycapRecorderAndIconEnablement() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))

        XCTAssertTrue(source.contains("ShortcutRecorderView"))
        XCTAssertTrue(source.contains("Record shortcut"))
        XCTAssertFalse(source.contains("Button(\"Record\")"))
        XCTAssertFalse(source.contains("Button(\"Disable\")"))
        XCTAssertTrue(source.contains("setEnabled(!shortcut.isEnabled)"))
        XCTAssertFalse(source.contains("Toggle(\"\", isOn: Binding("))
        XCTAssertTrue(source.contains("private var canRecordShortcut: Bool"))
        XCTAssertTrue(source.contains("guard canRecordShortcut else { return }"))
        XCTAssertTrue(source.contains("ShortcutKeycapGroupView(shortcut: shortcutTitle, isDisabled: !canRecordShortcut)"))
        XCTAssertTrue(source.contains(".disabled(!canRecordShortcut)"))
        XCTAssertTrue(source.contains("WindowActionDiagramView(action: shortcut.action)"))
    }
}
