import Foundation
import XCTest

final class UpdateMetadataTests: XCTestCase {
    func testInfoPlistDeclaresSparkleKeysAndBuildTag() throws {
        let plist = try loadInfoPlist()

        XCTAssertEqual(plist["SUFeedURL"] as? String, "https://woosublee.github.io/zap/appcast.xml")
        XCTAssertEqual(plist["SUPublicEDKey"] as? String, "AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=")
        XCTAssertEqual(plist["SUEnableAutomaticChecks"] as? Bool, true)
        XCTAssertEqual(plist["SUAutomaticallyUpdate"] as? Bool, false)
        XCTAssertEqual(plist["ZapBuildTag"] as? String, "local-unknown")
    }

    func testMakefileWritesBuildTagIntoBundle() throws {
        let makefile = try String(contentsOfFile: "Makefile", encoding: .utf8)

        XCTAssertTrue(makefile.contains("BUILD_TAG ?="))
        XCTAssertTrue(makefile.contains("plutil -replace ZapBuildTag -string \"$(BUILD_TAG)\""))
    }

    private func loadInfoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }
}
