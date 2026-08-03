import CoreGraphics
import XCTest
@testable import ZapApp
@testable import ZapCore

@MainActor
final class ShortcutHUDScreenResolverTests: XCTestCase {
    private let left = DisplayFrame(
        frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
        isMain: true
    )
    private let right = DisplayFrame(
        frame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
        visibleFrame: CGRect(x: 1000, y: 25, width: 1000, height: 775),
        isMain: false
    )

    func testTrustedAccessibilityUsesFocusedWindowDisplay() {
        let windows = StubHUDWindowController(
            frameResult: .success(CGRect(x: 1200, y: 100, width: 500, height: 500))
        )
        let resolver = ShortcutHUDScreenResolver(
            permission: StubHUDPermission(isTrusted: true),
            windows: windows,
            screens: StubHUDScreens(displayFrames: [left, right]),
            mouseLocation: { CGPoint(x: 100, y: 100) }
        )

        XCTAssertEqual(resolver.resolveScreenBeforeAction(), right)
        XCTAssertEqual(windows.frontmostWindowCallCount, 1)
    }

    func testUntrustedAccessibilitySkipsAXAndUsesMouseDisplay() {
        let windows = StubHUDWindowController(
            frameResult: .failure(AccessibilityWindowError.accessibilityAPIDisabled)
        )
        let permission = StubHUDPermission(isTrusted: false)
        let resolver = ShortcutHUDScreenResolver(
            permission: permission,
            windows: windows,
            screens: StubHUDScreens(displayFrames: [left, right]),
            mouseLocation: { CGPoint(x: 1500, y: 300) }
        )

        XCTAssertEqual(resolver.resolveScreenBeforeAction(), right)
        XCTAssertEqual(windows.frontmostWindowCallCount, 0)
        XCTAssertEqual(permission.requestPromptCallCount, 0)
    }

    func testAXFailureFallsBackToMouseThenPrimary() {
        let windows = StubHUDWindowController(
            frameResult: .failure(AccessibilityWindowError.focusedWindowMissing)
        )
        let mouseResolver = ShortcutHUDScreenResolver(
            permission: StubHUDPermission(isTrusted: true),
            windows: windows,
            screens: StubHUDScreens(displayFrames: [left, right]),
            mouseLocation: { CGPoint(x: 1500, y: 300) }
        )
        let primaryResolver = ShortcutHUDScreenResolver(
            permission: StubHUDPermission(isTrusted: true),
            windows: windows,
            screens: StubHUDScreens(displayFrames: [left, right]),
            mouseLocation: { CGPoint(x: 5000, y: 5000) }
        )

        XCTAssertEqual(mouseResolver.resolveScreenBeforeAction(), right)
        XCTAssertEqual(primaryResolver.resolveScreenBeforeAction(), left)
    }

    func testEmptyScreenInventoryReturnsNil() {
        let resolver = ShortcutHUDScreenResolver(
            permission: StubHUDPermission(isTrusted: false),
            windows: StubHUDWindowController(
                frameResult: .failure(AccessibilityWindowError.focusedWindowMissing)
            ),
            screens: StubHUDScreens(displayFrames: []),
            mouseLocation: { .zero }
        )

        XCTAssertNil(resolver.resolveScreenBeforeAction())
    }
}

private final class StubHUDPermission: AccessibilityPermissionChecking {
    let isTrusted: Bool
    private(set) var requestPromptCallCount = 0

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func requestPrompt() {
        requestPromptCallCount += 1
    }
}

private final class StubHUDWindowController: AccessibilityWindowControlling {
    let frameResult: Result<CGRect, Error>
    private(set) var frontmostWindowCallCount = 0

    init(frameResult: Result<CGRect, Error>) {
        self.frameResult = frameResult
    }

    func frontmostWindow() throws -> AccessibilityWindow {
        frontmostWindowCallCount += 1
        return .mock(applicationIdentifier: "com.example.App", elementID: "window")
    }

    func frame(of window: AccessibilityWindow) throws -> CGRect {
        try frameResult.get()
    }

    func setFrame(_ frame: CGRect, of window: AccessibilityWindow) throws {}
}

private struct StubHUDScreens: ScreenProviding {
    let displayFrames: [DisplayFrame]
}
