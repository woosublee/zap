import CoreGraphics
import XCTest
@testable import ZapCore

final class WindowPositionCalculatorTests: XCTestCase {
    private let visible = CGRect(x: 0, y: 25, width: 1441, height: 875)

    func testFullscreenUsesDestinationVisibleFrame() {
        let result = calculate(.fullscreen, window: CGRect(x: 100, y: 100, width: 400, height: 300))

        XCTAssertEqual(result.frame, visible)
        XCTAssertEqual(result.resolvedAction, .fullscreen)
    }

    func testCenterPreservesWindowSizeAndRoundsOriginLikeSpectacle() {
        let result = calculate(.center, window: CGRect(x: 0, y: 25, width: 400, height: 300))

        XCTAssertEqual(result.frame, CGRect(x: 521, y: 313, width: 400, height: 300))
    }

    func testCenterClampsOversizedWindowBeforeCalculatingOrigin() {
        let result = calculate(.center, window: CGRect(x: 0, y: 25, width: 2000, height: 1000))

        XCTAssertEqual(result.frame, visible)
    }

    func testHalvesUseVisibleFrameWithFloorAndRemainderPlacement() {
        XCTAssertEqual(calculate(.leftHalf).frame, CGRect(x: 0, y: 25, width: 720, height: 875))
        XCTAssertEqual(calculate(.rightHalf).frame, CGRect(x: 720, y: 25, width: 720, height: 875))
        XCTAssertEqual(calculate(.topHalf).frame, CGRect(x: 0, y: 463, width: 1441, height: 437))
        XCTAssertEqual(calculate(.bottomHalf).frame, CGRect(x: 0, y: 25, width: 1441, height: 437))
    }

    func testHalvesCycleBetweenHalfTwoThirdsAndOneThirdWhenRepeated() {
        let leftHalf = CGRect(x: 0, y: 25, width: 720, height: 875)
        let leftTwoThirds = CGRect(x: 0, y: 25, width: 960, height: 875)
        let leftOneThird = CGRect(x: 0, y: 25, width: 480, height: 875)
        XCTAssertEqual(calculate(.leftHalf, window: leftHalf).frame, leftTwoThirds)
        XCTAssertEqual(calculate(.leftHalf, window: leftTwoThirds).frame, leftOneThird)

        let rightHalf = CGRect(x: 720, y: 25, width: 720, height: 875)
        let rightTwoThirds = CGRect(x: 481, y: 25, width: 960, height: 875)
        let rightOneThird = CGRect(x: 961, y: 25, width: 480, height: 875)
        XCTAssertEqual(calculate(.rightHalf, window: rightHalf).frame, rightTwoThirds)
        XCTAssertEqual(calculate(.rightHalf, window: rightTwoThirds).frame, rightOneThird)
    }

    func testCornersUseVisibleFrameQuadrantsWithFloorAndRemainderPlacement() {
        XCTAssertEqual(calculate(.upperLeft).frame, CGRect(x: 0, y: 463, width: 720, height: 437))
        XCTAssertEqual(calculate(.upperRight).frame, CGRect(x: 720, y: 463, width: 720, height: 437))
        XCTAssertEqual(calculate(.lowerLeft).frame, CGRect(x: 0, y: 25, width: 720, height: 437))
        XCTAssertEqual(calculate(.lowerRight).frame, CGRect(x: 720, y: 25, width: 720, height: 437))
    }

    func testCornersCycleWidthWhereReasonableLikeSpectacle() {
        let upperLeft = CGRect(x: 0, y: 463, width: 720, height: 437)
        let upperLeftTwoThirds = CGRect(x: 0, y: 463, width: 960, height: 437)
        let upperLeftOneThird = CGRect(x: 0, y: 463, width: 480, height: 437)
        XCTAssertEqual(calculate(.upperLeft, window: upperLeft).frame, upperLeftTwoThirds)
        XCTAssertEqual(calculate(.upperLeft, window: upperLeftTwoThirds).frame, upperLeftOneThird)

        let lowerRight = CGRect(x: 720, y: 25, width: 720, height: 437)
        let lowerRightTwoThirds = CGRect(x: 481, y: 25, width: 960, height: 437)
        let lowerRightOneThird = CGRect(x: 961, y: 25, width: 480, height: 437)
        XCTAssertEqual(calculate(.lowerRight, window: lowerRight).frame, lowerRightTwoThirds)
        XCTAssertEqual(calculate(.lowerRight, window: lowerRightTwoThirds).frame, lowerRightOneThird)
    }

    func testNextAndPreviousThirdCycleAcrossHorizontalAndVerticalThirds() {
        let firstHorizontal = CGRect(x: 0, y: 25, width: 480, height: 875)
        let secondHorizontal = CGRect(x: 480, y: 25, width: 480, height: 875)
        let thirdHorizontal = CGRect(x: 960, y: 25, width: 480, height: 875)
        let firstVertical = CGRect(x: 0, y: 609, width: 1441, height: 291)
        let secondVertical = CGRect(x: 0, y: 318, width: 1441, height: 291)
        let thirdVertical = CGRect(x: 0, y: 27, width: 1441, height: 291)

        XCTAssertEqual(calculate(.nextThird, window: CGRect(x: 100, y: 100, width: 600, height: 400)).frame, firstHorizontal)
        XCTAssertEqual(calculate(.nextThird, window: firstHorizontal).frame, secondHorizontal)
        XCTAssertEqual(calculate(.nextThird, window: secondHorizontal).frame, thirdHorizontal)
        XCTAssertEqual(calculate(.nextThird, window: thirdHorizontal).frame, firstVertical)
        XCTAssertEqual(calculate(.nextThird, window: firstVertical).frame, secondVertical)
        XCTAssertEqual(calculate(.nextThird, window: secondVertical).frame, thirdVertical)
        XCTAssertEqual(calculate(.previousThird, window: firstHorizontal).frame, thirdVertical)
        XCTAssertEqual(calculate(.previousThird, window: thirdVertical).frame, secondVertical)
    }

    func testDisplayMovementCentersWindowWhenItFitsDestinationAndFullscreenWhenItDoesNot() {
        let source = CGRect(x: 0, y: 25, width: 1441, height: 875)
        let destination = CGRect(x: 2000, y: 50, width: 1000, height: 700)
        let input = WindowCalculationInput(
            windowFrame: CGRect(x: 0, y: 25, width: 500, height: 300),
            sourceVisibleFrame: source,
            destinationVisibleFrame: destination,
            action: .nextDisplay
        )

        XCTAssertEqual(WindowPositionCalculator().calculate(input).frame, CGRect(x: 2250, y: 250, width: 500, height: 300))

        let oversizedInput = WindowCalculationInput(
            windowFrame: CGRect(x: 0, y: 25, width: 1200, height: 800),
            sourceVisibleFrame: source,
            destinationVisibleFrame: destination,
            action: .previousDisplay
        )

        XCTAssertEqual(WindowPositionCalculator().calculate(oversizedInput).frame, destination)
    }

    func testLargerAndSmallerUseSpectacleThirtyPointSizeOffsetAndEdgeRules() {
        XCTAssertEqual(calculate(.larger, window: CGRect(x: 100, y: 200, width: 400, height: 300)).frame, CGRect(x: 85, y: 185, width: 430, height: 330))
        XCTAssertEqual(calculate(.smaller, window: CGRect(x: 100, y: 200, width: 400, height: 300)).frame, CGRect(x: 115, y: 215, width: 370, height: 270))

        XCTAssertEqual(calculate(.larger, window: CGRect(x: 0, y: 25, width: 720, height: 437)).frame, CGRect(x: 0, y: 25, width: 750, height: 467))
        XCTAssertEqual(calculate(.larger, window: CGRect(x: 711, y: 463, width: 730, height: 437)).frame, CGRect(x: 681, y: 433, width: 760, height: 467))
    }

    func testSmallerDoesNotShrinkBelowSpectacleMinimumQuarterSize() {
        let small = CGRect(x: 100, y: 100, width: 370, height: 220)

        XCTAssertEqual(calculate(.smaller, window: small).frame, small)
    }

    private func calculate(
        _ action: WindowAction,
        window: CGRect = CGRect(x: 100, y: 100, width: 600, height: 400)
    ) -> WindowCalculationResult {
        WindowPositionCalculator().calculate(WindowCalculationInput(
            windowFrame: window,
            sourceVisibleFrame: visible,
            destinationVisibleFrame: visible,
            action: action
        ))
    }
}
