import XCTest
@testable import ZapCore

final class NumberKeyTests: XCTestCase {
    func testDockIndexMapping() {
        XCTAssertEqual(NumberKey.one.dockIndex, 0)
        XCTAssertEqual(NumberKey.nine.dockIndex, 8)
        XCTAssertEqual(NumberKey.key(forDockIndex: 0), .one)
        XCTAssertEqual(NumberKey.key(forDockIndex: 8), .nine)
        XCTAssertNil(NumberKey.key(forDockIndex: 9))
    }

    func testMacKeyboardNumberKeyCodes() {
        XCTAssertEqual(NumberKey.one.carbonKeyCode, 18)
        XCTAssertEqual(NumberKey.two.carbonKeyCode, 19)
        XCTAssertEqual(NumberKey.three.carbonKeyCode, 20)
        XCTAssertEqual(NumberKey.four.carbonKeyCode, 21)
        XCTAssertEqual(NumberKey.five.carbonKeyCode, 23)
        XCTAssertEqual(NumberKey.six.carbonKeyCode, 22)
        XCTAssertEqual(NumberKey.seven.carbonKeyCode, 26)
        XCTAssertEqual(NumberKey.eight.carbonKeyCode, 28)
        XCTAssertEqual(NumberKey.nine.carbonKeyCode, 25)
    }
}
