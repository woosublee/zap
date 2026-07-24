import XCTest
@testable import ZapApp
@testable import ZapCore

final class ActiveApplicationToggleShortcutTests: XCTestCase {
    func testUnsetShortcutHasNoRegistrationOrDisplayValue() {
        let shortcut = ActiveApplicationToggleShortcut.unset

        XCTAssertNil(shortcut.keyCode)
        XCTAssertNil(shortcut.keyDisplayName)
        XCTAssertEqual(shortcut.modifiers, [])
        XCTAssertFalse(shortcut.canRegister)
        XCTAssertNil(shortcut.shortcutTitle)
    }

    func testConfiguredShortcutCanRegisterAndBuildsKeycapTitle() {
        let shortcut = ActiveApplicationToggleShortcut(
            keyCode: 123,
            keyDisplayName: "←",
            modifiers: [.control, .option]
        )

        XCTAssertTrue(shortcut.canRegister)
        XCTAssertEqual(shortcut.shortcutTitle, "⌃⌥←")
    }

    func testShortcutCodableRoundTripPreservesAllFields() throws {
        let shortcut = ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.command, .shift]
        )

        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(
            ActiveApplicationToggleShortcut.self,
            from: data
        )

        XCTAssertEqual(decoded, shortcut)
    }

    func testKeyWithoutModifiersIsNotRegisterable() {
        let shortcut = ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: []
        )

        XCTAssertFalse(shortcut.canRegister)
        XCTAssertNil(shortcut.shortcutTitle)
    }
}
