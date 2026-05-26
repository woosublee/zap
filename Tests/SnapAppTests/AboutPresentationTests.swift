import XCTest
@testable import SnapApp

final class AboutPresentationTests: XCTestCase {
    func testFormatsVersionBuildAndCreatorLink() {
        let info = AboutInfo(version: "0.1.0", buildNumber: "1", creator: "Woosub Lee")

        let presentation = AboutPresentation(appName: "Zap dev", info: info)

        XCTAssertEqual(presentation.appName, "Zap dev")
        XCTAssertEqual(presentation.versionLine, "Version 0.1.0 (1)")
        XCTAssertEqual(presentation.creatorLine, "Created by Woosub Lee")
        XCTAssertEqual(presentation.creatorURL, URL(string: "https://github.com/woosublee"))
    }

    func testFormatsAboutMenuLabel() {
        XCTAssertEqual(AboutPresentation.aboutMenuLabel(appName: "Zap dev"), "About Zap dev")
    }

    func testReadsBundleDisplayNameBeforeBundleName() {
        let appName = AboutPresentation.appName(infoDictionary: [
            "CFBundleDisplayName": "Zap dev",
            "CFBundleName": "Zap"
        ])

        XCTAssertEqual(appName, "Zap dev")
    }

    func testFallsBackToZapWhenBundleNameIsMissing() {
        XCTAssertEqual(AboutPresentation.appName(infoDictionary: [:]), "Zap")
    }
}
