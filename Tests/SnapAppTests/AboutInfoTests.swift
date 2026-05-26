import XCTest
@testable import SnapApp

final class AboutInfoTests: XCTestCase {
    func testReadsVersionBuildNumberAndCreator() {
        let info = AboutInfo.make(infoDictionary: [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42"
        ])

        XCTAssertEqual(info.version, "1.2.3")
        XCTAssertEqual(info.buildNumber, "42")
        XCTAssertEqual(info.creator, "Woosub Lee")
    }

    func testFallsBackWhenBundleValuesAreMissing() {
        let info = AboutInfo.make(infoDictionary: [:])

        XCTAssertEqual(info.version, "Unknown")
        XCTAssertEqual(info.buildNumber, "Unknown")
        XCTAssertEqual(info.creator, "Woosub Lee")
    }

    func testFallsBackWhenBundleValuesAreBlank() {
        let info = AboutInfo.make(infoDictionary: [
            "CFBundleShortVersionString": "  ",
            "CFBundleVersion": "\n"
        ])

        XCTAssertEqual(info.version, "Unknown")
        XCTAssertEqual(info.buildNumber, "Unknown")
        XCTAssertEqual(info.creator, "Woosub Lee")
    }
}
