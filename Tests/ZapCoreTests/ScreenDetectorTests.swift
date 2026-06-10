import CoreGraphics
import XCTest
@testable import ZapCore

final class ScreenDetectorTests: XCTestCase {
    private let leftDisplay = DisplayFrame(
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875),
        isMain: true
    )

    private let rightDisplay = DisplayFrame(
        frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055),
        isMain: false
    )

    private let upperDisplay = DisplayFrame(
        frame: CGRect(x: 0, y: 900, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 925, width: 1440, height: 875),
        isMain: false
    )

    func testOverlapAreaUsesIntersectionArea() {
        let detector = ScreenDetector()
        let window = CGRect(x: 1200, y: 100, width: 600, height: 400)

        XCTAssertEqual(detector.overlapArea(window, leftDisplay.frame), 240 * 400, accuracy: 0.001)
        XCTAssertEqual(detector.overlapArea(window, rightDisplay.frame), 360 * 400, accuracy: 0.001)
    }

    func testSourceDisplayChoosesLargestOverlap() throws {
        let detector = ScreenDetector()
        let window = CGRect(x: 1200, y: 100, width: 600, height: 400)

        let source = try detector.sourceDisplay(for: window, displays: [leftDisplay, rightDisplay])

        XCTAssertEqual(source, rightDisplay)
    }

    func testSourceDisplayFallsBackToMainDisplayWhenWindowHasNoOverlap() throws {
        let detector = ScreenDetector()
        let window = CGRect(x: -900, y: -900, width: 200, height: 200)

        let source = try detector.sourceDisplay(for: window, displays: [leftDisplay, rightDisplay])

        XCTAssertEqual(source, leftDisplay)
    }

    func testDestinationDisplayWrapsInSpectacleConsistentOrder() throws {
        let detector = ScreenDetector()
        let displays = [rightDisplay, upperDisplay, leftDisplay]

        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: leftDisplay, displays: displays), rightDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: rightDisplay, displays: displays), upperDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: upperDisplay, displays: displays), leftDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .previousDisplay, source: leftDisplay, displays: displays), upperDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .previousDisplay, source: rightDisplay, displays: displays), leftDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .previousDisplay, source: upperDisplay, displays: displays), rightDisplay)
    }

    func testSpectacleConsistentOrderKeepsOriginDisplayFirstThenSortsOtherDisplaysByDescendingX() throws {
        let detector = ScreenDetector()
        let origin = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            isMain: true
        )
        let left = DisplayFrame(
            frame: CGRect(x: -1000, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: -1000, y: 0, width: 1000, height: 800),
            isMain: false
        )
        let right = DisplayFrame(
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            isMain: false
        )
        let lowerRight = DisplayFrame(
            frame: CGRect(x: 2000, y: -800, width: 1000, height: 800),
            visibleFrame: CGRect(x: 2000, y: -800, width: 1000, height: 800),
            isMain: false
        )
        let displays = [left, lowerRight, right, origin]

        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: origin, displays: displays), lowerRight)
        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: lowerRight, displays: displays), right)
        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: right, displays: displays), left)
        XCTAssertEqual(try detector.destinationDisplay(for: .previousDisplay, source: origin, displays: displays), left)
    }

    func testDestinationVisibleFrameResolvesDisplayAction() throws {
        let detector = ScreenDetector()
        let window = CGRect(x: 1200, y: 100, width: 600, height: 400)
        let displays = [leftDisplay, rightDisplay]

        let result = try detector.displayContext(for: window, action: .nextDisplay, displays: displays)

        XCTAssertEqual(result.source, rightDisplay)
        XCTAssertEqual(result.destination, leftDisplay)
        XCTAssertEqual(result.sourceVisibleFrame, rightDisplay.visibleFrame)
        XCTAssertEqual(result.destinationVisibleFrame, leftDisplay.visibleFrame)
    }

    func testNonDisplayActionUsesSourceAsDestination() throws {
        let detector = ScreenDetector()
        let window = CGRect(x: 100, y: 100, width: 600, height: 400)

        let result = try detector.displayContext(for: window, action: .leftHalf, displays: [leftDisplay, rightDisplay])

        XCTAssertEqual(result.source, leftDisplay)
        XCTAssertEqual(result.destination, leftDisplay)
        XCTAssertEqual(result.destinationVisibleFrame, leftDisplay.visibleFrame)
    }

    func testEmptyDisplaysThrowNoDisplays() {
        let detector = ScreenDetector()

        XCTAssertThrowsError(try detector.sourceDisplay(for: .zero, displays: [])) { error in
            XCTAssertEqual(error as? WindowDomainError, .noDisplays)
        }
    }

    func testUnsupportedDisplayActionThrows() {
        let detector = ScreenDetector()

        XCTAssertThrowsError(try detector.destinationDisplay(for: .leftHalf, source: leftDisplay, displays: [leftDisplay])) { error in
            XCTAssertEqual(error as? WindowDomainError, .unsupportedDisplayAction(.leftHalf))
        }
    }
}
