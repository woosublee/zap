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
    }

    func testWindowShortcutRowUsesRecorderAndSupportsEnableDisable() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))

        XCTAssertTrue(source.contains("ShortcutRecorderView"))
        XCTAssertTrue(source.contains("Record"))
        XCTAssertTrue(source.contains("Disable"))
        XCTAssertTrue(source.contains("Toggle"))
        XCTAssertTrue(source.contains("setEnabled"))
        XCTAssertTrue(source.contains("shortcut.shortcutTitle ?? \"Not set\""))
    }
}
