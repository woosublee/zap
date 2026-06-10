import XCTest
@testable import ZapCore

final class WindowShortcutDefaultsTests: XCTestCase {
    func testDefaultsContainOneEnabledShortcutPerAction() {
        XCTAssertEqual(WindowShortcutDefaults.all.map(\.action), WindowAction.allCases)
        XCTAssertEqual(WindowShortcutDefaults.all.count, 18)
        XCTAssertTrue(WindowShortcutDefaults.all.allSatisfy(\.isEnabled))
    }

    func testLetterShortcutDefaults() {
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .center), WindowShortcut(action: .center, keyCode: 8, keyDisplayName: "C", modifiers: [.option, .command], isEnabled: true))
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .fullscreen), WindowShortcut(action: .fullscreen, keyCode: 3, keyDisplayName: "F", modifiers: [.option, .command], isEnabled: true))
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .undo), WindowShortcut(action: .undo, keyCode: 6, keyDisplayName: "Z", modifiers: [.option, .command], isEnabled: true))
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .redo), WindowShortcut(action: .redo, keyCode: 6, keyDisplayName: "Z", modifiers: [.option, .shift, .command], isEnabled: true))
    }

    func testArrowShortcutDisplaysMatchSpectacleDefaults() {
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .leftHalf).displayText, "⌥⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .rightHalf).displayText, "⌥⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .topHalf).displayText, "⌥⌘↑")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .bottomHalf).displayText, "⌥⌘↓")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .upperLeft).displayText, "⌃⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .lowerLeft).displayText, "⌃⇧⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .upperRight).displayText, "⌃⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .lowerRight).displayText, "⌃⇧⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .nextDisplay).displayText, "⌃⌥⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .previousDisplay).displayText, "⌃⌥⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .nextThird).displayText, "⌃⌥→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .previousThird).displayText, "⌃⌥←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .larger).displayText, "⌃⌥⇧→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .smaller).displayText, "⌃⌥⇧←")
    }
}
