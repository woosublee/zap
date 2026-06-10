import XCTest
@testable import ZapApp
@testable import ZapCore

final class WindowShortcutDisplayTests: XCTestCase {
    func testShortcutTitleResolvesKeyCodeWithCurrentInputSourceDisplayName() {
        let shortcut = WindowShortcut(
            action: .center,
            keyCode: 0,
            keyDisplayName: "A",
            modifiers: [.option],
            isEnabled: true
        )

        let title = WindowShortcutDisplay.shortcutTitle(for: shortcut) { keyCode, fallback in
            XCTAssertEqual(keyCode, 0)
            XCTAssertEqual(fallback, "A")
            return "ㅁ"
        }

        XCTAssertEqual(title, "⌥ㅁ")
    }

    func testShortcutTitleKeepsWindowModifierOrder() {
        let shortcut = WindowShortcut(
            action: .lowerLeft,
            keyCode: 123,
            keyDisplayName: "←",
            modifiers: [.command, .shift, .control],
            isEnabled: true
        )

        let title = WindowShortcutDisplay.shortcutTitle(for: shortcut) { _, _ in "←" }

        XCTAssertEqual(title, "⌃⇧⌘←")
    }

    func testShortcutTitleReturnsNilForIncompleteShortcut() {
        let shortcut = WindowShortcut(
            action: .center,
            keyCode: nil,
            keyDisplayName: nil,
            modifiers: [.option],
            isEnabled: true
        )

        XCTAssertNil(WindowShortcutDisplay.shortcutTitle(for: shortcut))
    }
}
