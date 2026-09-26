import CoreGraphics
import XCTest
@testable import ZapApp

final class PermissionGuidePresentationTests: XCTestCase {
    func testThrottleAllowsOnlyFirstStart() {
        var throttle = PermissionGuideThrottle()

        XCTAssertTrue(throttle.shouldStart())
        XCTAssertFalse(throttle.shouldStart())
        XCTAssertFalse(throttle.shouldStart())
    }

    func testPaneNameUsesAccessibilityBeforeMacOS27() {
        let version = OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0)

        XCTAssertEqual(AccessibilityPaneName.title(for: version), "Accessibility")
    }

    func testPaneNameUsesDeviceControlOnMacOS27AndLater() {
        let v27 = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        let v28 = OperatingSystemVersion(majorVersion: 28, minorVersion: 1, patchVersion: 0)

        XCTAssertEqual(AccessibilityPaneName.title(for: v27), "Device Control and Data Access")
        XCTAssertEqual(AccessibilityPaneName.title(for: v28), "Device Control and Data Access")
    }

    func testSourceFrameIsCenteredOnPoint() {
        let frame = PermissionGuideSourceFrame.around(CGPoint(x: 100, y: 200))

        XCTAssertEqual(frame, CGRect(x: 84, y: 184, width: 32, height: 32))
    }
}
