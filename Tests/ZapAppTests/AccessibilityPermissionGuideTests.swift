import CoreGraphics
import XCTest
@testable import ZapApp

@MainActor
final class AccessibilityPermissionGuideTests: XCTestCase {
    func testStartAuthorizesWithSourceFrameWhenUntrusted() {
        var authorizedFrames: [CGRect?] = []
        let guide = AccessibilityPermissionGuide(
            permission: StubGuidePermission(isTrusted: false),
            authorize: { authorizedFrames.append($0) }
        )
        let frame = CGRect(x: 10, y: 20, width: 32, height: 32)

        guide.start(sourceFrame: frame)
        guide.start(sourceFrame: nil)

        XCTAssertEqual(authorizedFrames, [frame, nil])
    }

    func testStartDoesNothingWhenAlreadyTrusted() {
        var authorizeCallCount = 0
        let guide = AccessibilityPermissionGuide(
            permission: StubGuidePermission(isTrusted: true),
            authorize: { _ in authorizeCallCount += 1 }
        )

        guide.start(sourceFrame: nil)

        XCTAssertEqual(authorizeCallCount, 0)
    }
}

private struct StubGuidePermission: AccessibilityPermissionChecking {
    let isTrusted: Bool

    func requestPrompt() {}
}
