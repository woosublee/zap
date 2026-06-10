import XCTest
@testable import ZapCore

final class WindowActionTests: XCTestCase {
    func testAllActionsUseSpectacleOrder() {
        XCTAssertEqual(WindowAction.allCases, [
            .center,
            .fullscreen,
            .leftHalf,
            .rightHalf,
            .topHalf,
            .bottomHalf,
            .upperLeft,
            .upperRight,
            .lowerLeft,
            .lowerRight,
            .nextDisplay,
            .previousDisplay,
            .nextThird,
            .previousThird,
            .larger,
            .smaller,
            .undo,
            .redo
        ])
    }

    func testDisplayNamesMatchSettingsLabels() {
        XCTAssertEqual(WindowAction.center.displayName, "Center")
        XCTAssertEqual(WindowAction.fullscreen.displayName, "Fullscreen")
        XCTAssertEqual(WindowAction.leftHalf.displayName, "Left Half")
        XCTAssertEqual(WindowAction.rightHalf.displayName, "Right Half")
        XCTAssertEqual(WindowAction.topHalf.displayName, "Top Half")
        XCTAssertEqual(WindowAction.bottomHalf.displayName, "Bottom Half")
        XCTAssertEqual(WindowAction.upperLeft.displayName, "Upper Left")
        XCTAssertEqual(WindowAction.upperRight.displayName, "Upper Right")
        XCTAssertEqual(WindowAction.lowerLeft.displayName, "Lower Left")
        XCTAssertEqual(WindowAction.lowerRight.displayName, "Lower Right")
        XCTAssertEqual(WindowAction.nextDisplay.displayName, "Next Display")
        XCTAssertEqual(WindowAction.previousDisplay.displayName, "Previous Display")
        XCTAssertEqual(WindowAction.nextThird.displayName, "Next Third")
        XCTAssertEqual(WindowAction.previousThird.displayName, "Previous Third")
        XCTAssertEqual(WindowAction.larger.displayName, "Larger")
        XCTAssertEqual(WindowAction.smaller.displayName, "Smaller")
        XCTAssertEqual(WindowAction.undo.displayName, "Undo")
        XCTAssertEqual(WindowAction.redo.displayName, "Redo")
    }

    func testCategoriesSeparatePositioningDisplaySizingAndHistory() {
        XCTAssertEqual(WindowAction.center.category, .positioning)
        XCTAssertEqual(WindowAction.upperRight.category, .positioning)
        XCTAssertEqual(WindowAction.nextDisplay.category, .display)
        XCTAssertEqual(WindowAction.previousDisplay.category, .display)
        XCTAssertEqual(WindowAction.nextThird.category, .sizing)
        XCTAssertEqual(WindowAction.larger.category, .sizing)
        XCTAssertEqual(WindowAction.undo.category, .history)
        XCTAssertEqual(WindowAction.redo.category, .history)
    }
}
