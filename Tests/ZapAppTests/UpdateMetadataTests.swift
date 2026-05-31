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

    func testInfoPlistUsesSparkleDefaultUpdateCheckInterval() throws {
        let plist = try loadInfoPlist()

        XCTAssertNil(plist["SUUpdateCheckInterval"])
    }

    func testMakefileWritesBuildTagIntoBundle() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("BUILD_TAG ?="))
        XCTAssertTrue(makefile.contains("plutil -replace ZapBuildTag -string \"$(BUILD_TAG)\""))
    }

    func testMakefileUsesZapReleaseSigningIdentity() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("RELEASE_CODESIGN_IDENTITY ?= zap"))
        XCTAssertTrue(makefile.contains("LOCAL_CERTIFICATE_IDENTITY ?= $(RELEASE_CODESIGN_IDENTITY)"))
    }

    func testMakefileUsesOfficialSparkleKeychainAccount() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("SPARKLE_ACCOUNT ?= com.woosublee.Zap.sparkle.ed25519"))
        XCTAssertTrue(makefile.contains("security find-generic-password -s \"https://sparkle-project.org\" -a \"$(SPARKLE_ACCOUNT)\""))
    }

    private func loadInfoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func loadMakefile() throws -> String {
        try String(contentsOfFile: "Makefile", encoding: .utf8)
    }
}
