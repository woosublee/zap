import AppKit
import SwiftUI
import XCTest
@testable import ZapApp

final class AboutWindowPresenterTests: XCTestCase {
    @MainActor
    func testMakeWindowCreatesFloatingAboutWindow() {
        let info = AboutInfo(version: "1.2.3", buildNumber: "42", creator: "Woosub Lee")

        let window: NSWindow = AboutWindowPresenter.makeWindow(info: info, appName: "Zap dev")

        XCTAssertEqual(window.title, "About Zap dev")
        XCTAssertTrue(window.styleMask.contains(NSWindow.StyleMask.titled))
        XCTAssertTrue(window.styleMask.contains(NSWindow.StyleMask.closable))
        XCTAssertEqual(window.level, NSWindow.Level.floating)
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertNotNil(window.contentViewController as? NSHostingController<AboutView>)
    }
}
