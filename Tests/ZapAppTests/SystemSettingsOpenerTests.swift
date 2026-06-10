import XCTest
@testable import ZapApp

final class SystemSettingsOpenerTests: XCTestCase {
    func testOpenAccessibilitySettingsUsesAccessibilityPrivacyURL() {
        var capturedURL: URL?
        let opener = SystemSettingsOpener(openURL: { url in
            capturedURL = url
            return true
        })

        let didOpen = opener.openAccessibilitySettings()

        XCTAssertTrue(didOpen)
        XCTAssertEqual(capturedURL?.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func testOpenAccessibilitySettingsReturnsWorkspaceResult() {
        let opener = SystemSettingsOpener(openURL: { _ in false })

        XCTAssertFalse(opener.openAccessibilitySettings())
    }
}
