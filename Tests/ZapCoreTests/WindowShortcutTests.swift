import XCTest
@testable import ZapCore

final class WindowShortcutTests: XCTestCase {
    func testShortcutIdentityUsesAction() {
        let shortcut = WindowShortcut(
            action: .center,
            keyCode: 8,
            keyDisplayName: "C",
            modifiers: [.option, .command],
            isEnabled: true
        )

        XCTAssertEqual(shortcut.id, WindowAction.center.id)
    }

    func testDisplayTextUsesStableModifierOrder() {
        let shortcut = WindowShortcut(
            action: .lowerLeft,
            keyCode: 123,
            keyDisplayName: "←",
            modifiers: [.command, .shift, .control],
            isEnabled: true
        )

        XCTAssertEqual(shortcut.shortcutTitle, "⌃⇧⌘←")
        XCTAssertEqual(shortcut.displayText, "⌃⇧⌘←")
    }

    func testDisabledOrIncompleteShortcutCannotRegisterAndDisplaysOff() {
        let disabled = WindowShortcut(action: .center, keyCode: 8, keyDisplayName: "C", modifiers: [.option], isEnabled: false)
        let missingKey = WindowShortcut(action: .center, keyCode: nil, keyDisplayName: nil, modifiers: [.option], isEnabled: true)
        let missingDisplayName = WindowShortcut(action: .center, keyCode: 8, keyDisplayName: "", modifiers: [.option], isEnabled: true)
        let missingModifiers = WindowShortcut(action: .center, keyCode: 8, keyDisplayName: "C", modifiers: [], isEnabled: true)

        XCTAssertFalse(disabled.canRegister)
        XCTAssertFalse(missingKey.canRegister)
        XCTAssertFalse(missingDisplayName.canRegister)
        XCTAssertFalse(missingModifiers.canRegister)
        XCTAssertEqual(disabled.shortcutTitle, "⌥C")
        XCTAssertNil(missingKey.shortcutTitle)
        XCTAssertNil(missingDisplayName.shortcutTitle)
        XCTAssertNil(missingModifiers.shortcutTitle)
        XCTAssertEqual(disabled.displayText, "Off")
        XCTAssertEqual(missingKey.displayText, "Off")
        XCTAssertEqual(missingDisplayName.displayText, "Off")
        XCTAssertEqual(missingModifiers.displayText, "Off")
    }

    func testShortcutCodableRoundTrip() throws {
        let shortcut = WindowShortcut(
            action: .redo,
            keyCode: 6,
            keyDisplayName: "Z",
            modifiers: [.option, .shift, .command],
            isEnabled: true
        )

        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(WindowShortcut.self, from: data)

        XCTAssertEqual(decoded, shortcut)
    }
}
