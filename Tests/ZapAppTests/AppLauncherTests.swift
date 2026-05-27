import XCTest
@testable import ZapApp

final class AppLauncherTests: XCTestCase {
    func testFinderActivationRequestsAllFinderWindowsForward() throws {
        let source = try appLauncherSource()
        let activateFinderStart = try XCTUnwrap(source.range(of: "func activateFinder()"))
        let sendReopenCall = try XCTUnwrap(source.range(of: "sendReopenEvent(to: runningApp)", range: activateFinderStart.lowerBound..<source.endIndex))
        let runningFinderActivation = source[activateFinderStart.lowerBound..<sendReopenCall.upperBound]

        XCTAssertTrue(
            runningFinderActivation.contains(".activateAllWindows"),
            "Running Finder activation should bring all existing Finder windows forward."
        )
    }

    private func appLauncherSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent("Sources/ZapApp/Services/AppLauncher.swift")
        return try String(contentsOf: sourceURL)
    }
}
