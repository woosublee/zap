import AppKit
import XCTest
@testable import ZapApp

@MainActor
final class AppLauncherTests: XCTestCase {
    private let terminal = DockItem(
        name: "Terminal",
        url: URL(fileURLWithPath: "/Applications/Terminal.app"),
        bundleIdentifier: "com.apple.Terminal"
    )

    func testRunningApplicationActivationSuccessCompletesActivatedWithoutBeep() {
        var outcomes: [AppLaunchOutcome] = []
        var beepCount = 0
        let launcher = AppLauncher(
            runningApplication: { _ in NSRunningApplication.current },
            activateRunningApplication: { _, _ in true },
            openApplication: { _, _, _ in
                XCTFail("A running app must not be opened.")
            },
            beep: { beepCount += 1 }
        )

        launcher.activateOrLaunch(terminal) { outcomes.append($0) }

        XCTAssertEqual(outcomes, [.activated])
        XCTAssertEqual(beepCount, 0)
    }

    func testRunningApplicationActivationFailureBeepsOnceAndCompletesFailed() {
        var outcomes: [AppLaunchOutcome] = []
        var beepCount = 0
        let launcher = AppLauncher(
            runningApplication: { _ in NSRunningApplication.current },
            activateRunningApplication: { _, _ in false },
            openApplication: { _, _, _ in
                XCTFail("A running app must not be opened.")
            },
            beep: { beepCount += 1 }
        )

        launcher.activateOrLaunch(terminal) { outcomes.append($0) }

        XCTAssertEqual(outcomes, [.failed])
        XCTAssertEqual(beepCount, 1)
    }

    func testOpenSuccessCompletesLaunchedOnlyAfterWorkspaceCompletion() async {
        var workspaceCompletion: ((NSRunningApplication?, Error?) -> Void)?
        var outcomes: [AppLaunchOutcome] = []
        var beepCount = 0
        let launcher = AppLauncher(
            runningApplication: { _ in nil },
            activateRunningApplication: { _, _ in
                XCTFail("No app is running.")
                return false
            },
            openApplication: { _, _, completion in
                workspaceCompletion = completion
            },
            beep: { beepCount += 1 }
        )

        launcher.activateOrLaunch(terminal) { outcomes.append($0) }
        XCTAssertTrue(outcomes.isEmpty)

        workspaceCompletion?(NSRunningApplication.current, nil)
        await Task.yield()

        XCTAssertEqual(outcomes, [.launched])
        XCTAssertEqual(beepCount, 0)
    }

    func testOpenErrorBeepsOnceAndCompletesFailed() async {
        var outcomes: [AppLaunchOutcome] = []
        var beepCount = 0
        let launcher = AppLauncher(
            runningApplication: { _ in nil },
            activateRunningApplication: { _, _ in false },
            openApplication: { _, _, completion in
                completion(nil, TestOpenError())
            },
            beep: { beepCount += 1 }
        )

        launcher.activateOrLaunch(terminal) { outcomes.append($0) }
        await Task.yield()

        XCTAssertEqual(outcomes, [.failed])
        XCTAssertEqual(beepCount, 1)
    }

    func testOpenMissingRunningApplicationBeepsOnceAndCompletesFailed() async {
        var outcomes: [AppLaunchOutcome] = []
        var beepCount = 0
        let launcher = AppLauncher(
            runningApplication: { _ in nil },
            activateRunningApplication: { _, _ in false },
            openApplication: { _, _, completion in
                completion(nil, nil)
            },
            beep: { beepCount += 1 }
        )

        launcher.activateOrLaunch(terminal) { outcomes.append($0) }
        await Task.yield()

        XCTAssertEqual(outcomes, [.failed])
        XCTAssertEqual(beepCount, 1)
    }

    func testOpenCompletionIsDeliveredOnlyOnce() async {
        var outcomes: [AppLaunchOutcome] = []
        var beepCount = 0
        let launcher = AppLauncher(
            runningApplication: { _ in nil },
            activateRunningApplication: { _, _ in false },
            openApplication: { _, _, completion in
                completion(NSRunningApplication.current, nil)
                completion(nil, TestOpenError())
            },
            beep: { beepCount += 1 }
        )

        launcher.activateOrLaunch(terminal) { outcomes.append($0) }
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(outcomes, [.launched])
        XCTAssertEqual(beepCount, 0)
    }

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
                return true
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

private struct TestOpenError: Error {}
