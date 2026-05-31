import Foundation
import XCTest

final class UpdateMetadataTests: XCTestCase {
    func testInfoPlistDeclaresSparkleKeysAndBuildTag() throws {
        let plist = try loadInfoPlist()

        XCTAssertEqual(plist["SUFeedURL"] as? String, "https://github.com/woosublee/zap/releases/latest/download/appcast.xml")
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

    func testMakefileUsesZapSigningIdentityForEveryBuild() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("CODESIGN_IDENTITY ?= zap"))
        XCTAssertTrue(makefile.contains("RELEASE_CODESIGN_IDENTITY ?= $(CODESIGN_IDENTITY)"))
        XCTAssertTrue(makefile.contains("LOCAL_CERTIFICATE_IDENTITY ?= $(CODESIGN_IDENTITY)"))
        XCTAssertTrue(makefile.contains("dev-build:\n\t$(MAKE) sign APP_NAME=\"$(DEV_APP_NAME)\" BUNDLE_ID=\"$(DEV_BUNDLE_ID)\" BUILD_DIR=\"$(DEV_BUILD_DIR)\""))
        XCTAssertFalse(makefile.contains("CODESIGN_IDENTITY=\"-\""))
    }

    func testMakefileUsesOfficialSparkleKeychainAccount() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("SPARKLE_ACCOUNT ?= com.woosublee.Zap.sparkle.ed25519"))
        XCTAssertTrue(makefile.contains("security find-generic-password -s \"https://sparkle-project.org\" -a \"$(SPARKLE_ACCOUNT)\""))
    }

    func testMakefileSignsNestedSparkleComponentsForAnyIdentity() throws {
        let makefile = try loadMakefile()

        XCTAssertFalse(makefile.contains("@if [ \"$(CODESIGN_IDENTITY)\" != \"-\" ]; then"))
        XCTAssertTrue(makefile.contains("codesign --force $(CODESIGN_OPTIONS) --sign \"$(CODESIGN_IDENTITY)\" \"$$item\""))
        XCTAssertTrue(makefile.contains("codesign --force $(CODESIGN_OPTIONS) --sign \"$(CODESIGN_IDENTITY)\" \"$(FRAMEWORKS_DIR)/Sparkle.framework\""))
    }

    func testMakefileCleansBundleBeforeEmbeddingSparkle() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("bundle: swift-build $(INFO_PLIST) $(ENTITLEMENTS)"))
        XCTAssertFalse(makefile.contains("bundle: swift-build embed-sparkle $(INFO_PLIST) $(ENTITLEMENTS)"))
        XCTAssertTrue(makefile.contains("rm -rf \"$(APP_BUNDLE)\""))
        XCTAssertTrue(makefile.contains("$(MAKE) embed-sparkle CONFIGURATION=\"$(CONFIGURATION)\" BUILD_DIR=\"$(BUILD_DIR)\""))
    }

    func testMakefileUsesSimpleTrapSyntax() throws {
        let makefile = try loadMakefile()

        XCTAssertTrue(makefile.contains("trap 'rm -rf \"$$tmpdir\"' EXIT"))
        XCTAssertFalse(makefile.contains("trap 'rm -rf \"'\"'$$tmpdir'\"'\"' EXIT"))
    }

    private func loadInfoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: packageRootURL.appendingPathComponent("Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func loadMakefile() throws -> String {
        try String(contentsOf: packageRootURL.appendingPathComponent("Makefile"), encoding: .utf8)
    }

    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
