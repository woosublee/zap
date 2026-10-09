import XCTest
@testable import ZapApp

final class ShortcutKeycapLabelTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDisplayReplacesMultiCharacterKeyNamesWithSymbols() {
        XCTAssertEqual(ShortcutKeycapLabel.display("Return"), "↩")
        XCTAssertEqual(ShortcutKeycapLabel.display("Tab"), "⇥")
        XCTAssertEqual(ShortcutKeycapLabel.display("Delete"), "⌫")
        XCTAssertEqual(ShortcutKeycapLabel.display("Esc"), "⎋")
    }

    func testDisplayKeepsOtherLabelsUnchanged() {
        XCTAssertEqual(ShortcutKeycapLabel.display("Space"), "Space")
        XCTAssertEqual(ShortcutKeycapLabel.display("F12"), "F12")
        XCTAssertEqual(ShortcutKeycapLabel.display("ㅐ"), "ㅐ")
        XCTAssertEqual(ShortcutKeycapLabel.display("⌘"), "⌘")
        XCTAssertEqual(ShortcutKeycapLabel.display("Not set"), "Not set")
    }

    func testKeycapViewRendersDisplayLabelOnOneLineAndKeepsOriginalAccessibilityLabel() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("Text(displayLabel)"))
        XCTAssertTrue(source.contains(".lineLimit(1)\n            .fixedSize()"))
        XCTAssertTrue(source.contains(".padding(.horizontal, displayLabel.count > 1 ? 7 : 0)"))
        XCTAssertTrue(source.contains(".accessibilityLabel(label)"))
    }
}
