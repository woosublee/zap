import AppKit
import XCTest
@testable import ZapApp

final class AppLauncherTests: XCTestCase {
    func testFinderActivationRequestsAllFinderWindowsForward() {
        var capturedBundleIdentifier: String?
        var capturedActivationOptions: NSApplication.ActivationOptions?
        var didSendReopenEvent = false

        let launcher = AppLauncher(
            runningApplication: { bundleIdentifier in
                capturedBundleIdentifier = bundleIdentifier
                return NSRunningApplication.current
            },
            activateRunningApplication: { _, options in
                capturedActivationOptions = options
            },
            applicationURL: { _ in
                XCTFail("Running Finder should not resolve an application URL.")
                return nil
            },
            openApplication: { _, _, _ in
                XCTFail("Running Finder should not be opened again.")
            },
            beep: {
                XCTFail("Running Finder activation should not beep.")
            },
            sendReopenEvent: { _ in
                didSendReopenEvent = true
            }
        )

        launcher.activateFinder()

        XCTAssertEqual(capturedBundleIdentifier, "com.apple.finder")
        XCTAssertTrue(capturedActivationOptions?.contains(.activateAllWindows) == true)
        XCTAssertTrue(didSendReopenEvent)
    }
}
