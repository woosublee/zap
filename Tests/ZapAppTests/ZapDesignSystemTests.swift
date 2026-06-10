import XCTest

final class ZapDesignSystemTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDesignSystemDefinesSharedCardsRowsAndKeycaps() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("struct SettingsCard"))
        XCTAssertTrue(source.contains("struct SettingsRow"))
        XCTAssertTrue(source.contains("struct ShortcutKeycapView"))
        XCTAssertTrue(source.contains("struct ShortcutKeycapGroupView"))
        XCTAssertTrue(source.contains("cache_control") == false)
    }

    func testShortcutKeycapGroupKeepsLiteralPlusKeyToken() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("if token == \"+\", characterIndex == shortcut.indices.last"))
        XCTAssertFalse(source.contains("token != \"+\" && token != \" \""))
    }
}
