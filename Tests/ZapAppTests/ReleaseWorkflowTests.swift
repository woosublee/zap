import XCTest

final class ReleaseWorkflowTests: XCTestCase {
    func testReleaseWorkflowBuildsAndUploadsNotarizedDMG() throws {
        let root = repositoryRoot()
        let workflow = try String(contentsOf: root.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)
        let makefile = try String(contentsOf: root.appendingPathComponent("Makefile"), encoding: .utf8)
        let appcastScript = try String(contentsOf: root.appendingPathComponent("scripts/generate-sparkle-appcast.sh"), encoding: .utf8)
        let releaseLocal = try String(contentsOf: root.appendingPathComponent("scripts/release-local.sh"), encoding: .utf8)
        let secretRegistration = try String(contentsOf: root.appendingPathComponent("scripts/register-release-secrets.sh"), encoding: .utf8)
        let notarizeScript = try String(contentsOf: root.appendingPathComponent("scripts/notarize.sh"), encoding: .utf8)
        let verifyDMGScript = try String(contentsOf: root.appendingPathComponent("scripts/verify-dmg.sh"), encoding: .utf8)

        XCTAssertTrue(makefile.contains("CODESIGN_IDENTITY ?= Developer ID Application: Woosub Lee (2L6ZW98RCP)"))
        XCTAssertTrue(makefile.contains("RELEASE_CODESIGN_IDENTITY ?= $(CODESIGN_IDENTITY)"))
        XCTAssertTrue(makefile.contains("print-app-version:"))
        XCTAssertTrue(makefile.contains("print-build-number:"))
        XCTAssertTrue(makefile.contains("print-build-tag:"))
        XCTAssertTrue(makefile.contains("printf 'v%s\\n' \"$(VERSION)\""))
        XCTAssertTrue(makefile.contains("REPOSITORY ?= woosublee/zap"))
        XCTAssertTrue(makefile.contains("verify-dmg:"))
        XCTAssertTrue(makefile.contains("APP_NAME=\"$(PROD_APP_NAME)\" scripts/verify-dmg.sh \"$(RELEASE_DMG)\""))
        XCTAssertTrue(makefile.contains("sign-dmg:"))
        XCTAssertTrue(makefile.contains("prepare-release-dmg:"))
        XCTAssertTrue(makefile.contains("codesign --force --timestamp --sign \"$(CODESIGN_IDENTITY)\" \"$(RELEASE_DMG)\""))
        XCTAssertTrue(makefile.contains("NOTARY_PROFILE ?= woosublee-notary"))
        XCTAssertTrue(makefile.contains("notarize-app:"))
        XCTAssertTrue(makefile.contains("xcrun stapler staple \"$(PROD_APP_BUNDLE)\""))
        XCTAssertTrue(makefile.contains("notarize-dmg:"))
        XCTAssertTrue(makefile.contains("NOTARY_PROFILE=\"$(NOTARY_PROFILE)\" NOTARY_KEYCHAIN=\"$(NOTARY_KEYCHAIN)\" scripts/notarize.sh \"$(RELEASE_DMG)\""))
        XCTAssertTrue(makefile.contains("xcrun stapler staple \"$(RELEASE_DMG)\""))
        XCTAssertTrue(makefile.contains("VERIFY_GATEKEEPER=1 APP_NAME=\"$(PROD_APP_NAME)\" scripts/verify-dmg.sh \"$(RELEASE_DMG)\""))
        XCTAssertTrue(makefile.contains("release: check-codesign-identity appcast"))
        assert("$(MAKE) notarize-app", appearsBefore: "ditto -c -k --keepParent \"$(PROD_APP_BUNDLE)\" \"$(RELEASE_ARCHIVE)\"", in: makefile)
        assert("$(MAKE) sign-dmg CODESIGN_IDENTITY=\"$(RELEASE_CODESIGN_IDENTITY)\"", appearsBefore: "$(MAKE) notarize-dmg", in: makefile)
        assert("$(MAKE) notarize-dmg", appearsBefore: "$(MAKE) verify-notarized-dmg", in: makefile)

        XCTAssertTrue(notarizeScript.contains("xcrun notarytool submit"))
        XCTAssertTrue(notarizeScript.contains("--keychain-profile \"$profile\""))
        XCTAssertTrue(notarizeScript.contains("NOTARY_KEYCHAIN"))
        XCTAssertTrue(notarizeScript.contains("\"$status\" != \"Accepted\""))
        XCTAssertTrue(notarizeScript.contains("xcrun notarytool log"))

        XCTAssertTrue(verifyDMGScript.contains("spctl -a -vv -t open --context context:primary-signature \"$dmg_path\""))
        XCTAssertTrue(verifyDMGScript.contains("xcrun stapler validate \"$app_path\""))
        XCTAssertTrue(verifyDMGScript.contains("spctl -a -vv -t exec \"$app_path\""))
        XCTAssertTrue(makefile.contains("SPARKLE_SIGN_UPDATE=\"$(SPARKLE_SIGN_UPDATE)\" scripts/generate-sparkle-appcast.sh"))
        XCTAssertFalse(makefile.contains("CODESIGN_IDENTITY=\"-\""))

        XCTAssertTrue(appcastScript.contains("REPOSITORY=\"${REPOSITORY:-woosublee/zap}\""))
        XCTAssertTrue(appcastScript.contains("APP_NAME=\"${APP_NAME:-Zap}\""))
        XCTAssertTrue(appcastScript.contains("SPARKLE_KEYCHAIN_ACCOUNT=\"${SPARKLE_KEYCHAIN_ACCOUNT:-com.woosublee.Zap.sparkle.ed25519}\""))
        XCTAssertTrue(appcastScript.contains("security find-generic-password"))
        XCTAssertTrue(appcastScript.contains("SPARKLE_PRIVATE_KEY"))
        XCTAssertTrue(appcastScript.contains("sign_update"))
        XCTAssertTrue(appcastScript.contains("--ed-key-file -"))
        XCTAssertTrue(appcastScript.contains("tools_dir=\"$tools_parent/Sparkle-${SPARKLE_VERSION}\""))
        XCTAssertTrue(appcastScript.contains("sed -n '1p'"))
        XCTAssertTrue(appcastScript.contains("wc -c < \"$DMG_PATH\""))
        XCTAssertTrue(appcastScript.contains("LC_ALL=C date"))
        XCTAssertFalse(appcastScript.contains("-perm +111"))
        XCTAssertFalse(appcastScript.contains("-quit"))
        XCTAssertFalse(appcastScript.contains("stat -f%z"))

        XCTAssertTrue(releaseLocal.contains("CODESIGN_IDENTITY=\"${CODESIGN_IDENTITY:-Developer ID Application: Woosub Lee (2L6ZW98RCP)}\""))
        XCTAssertTrue(releaseLocal.contains("security find-identity -v -p codesigning"))
        XCTAssertTrue(releaseLocal.contains("xcrun notarytool history --keychain-profile \"$NOTARY_PROFILE\""))
        XCTAssertTrue(releaseLocal.contains("gh repo view --json nameWithOwner --jq .nameWithOwner"))
        XCTAssertTrue(releaseLocal.contains("make VERSION=\"$VERSION\" BUILD_NUMBER=\"$BUILD_NUMBER\" BUILD_TAG=\"$RELEASE_TAG\" CODESIGN_IDENTITY=\"$CODESIGN_IDENTITY\" NOTARY_PROFILE=\"$NOTARY_PROFILE\" prepare-release-dmg"))
        XCTAssertTrue(releaseLocal.contains("make -s check-eddsa-key"))
        XCTAssertTrue(releaseLocal.contains("ALLOW_LOCAL_RELEASE_CLOBBER"))
        XCTAssertTrue(releaseLocal.contains("gh release view \"$RELEASE_TAG\" --repo \"$REPOSITORY\""))
        XCTAssertTrue(releaseLocal.contains("gh release upload \"$RELEASE_TAG\" \"$DMG_PATH\" \"$APPCAST_PATH\" --repo \"$REPOSITORY\"\n"))
        XCTAssertTrue(releaseLocal.contains("gh release upload \"$RELEASE_TAG\" \"$DMG_PATH\" \"$APPCAST_PATH\" --repo \"$REPOSITORY\" --clobber"))
        XCTAssertFalse(releaseLocal.contains("CODESIGN_IDENTITY=-"))

        XCTAssertTrue(secretRegistration.contains("DEVELOPER_ID_CERTIFICATE_BASE64"))
        XCTAssertTrue(secretRegistration.contains("DEVELOPER_ID_CERTIFICATE_PASSWORD"))
        XCTAssertTrue(secretRegistration.contains("gh secret set ASC_KEY_ID"))
        XCTAssertTrue(secretRegistration.contains("gh secret set ASC_ISSUER_ID"))
        XCTAssertTrue(secretRegistration.contains("gh secret set ASC_KEY_P8_BASE64"))
        XCTAssertTrue(secretRegistration.contains("SPARKLE_PRIVATE_KEY"))
        XCTAssertTrue(secretRegistration.contains("*\"Developer ID Application\"*"))
        XCTAssertTrue(secretRegistration.contains("private_key_pattern='BEGIN ([A-Z]+ )?PRIVATE KEY'"))
        XCTAssertTrue(secretRegistration.contains("make -s check-eddsa-key"))
        XCTAssertTrue(secretRegistration.contains("LEGACY_CERTIFICATE_SECRETS=(ZAP_CERTIFICATE_BASE64 ZAP_CERTIFICATE_PASSWORD)"))
        XCTAssertTrue(secretRegistration.contains("gh secret delete \"$legacy_secret\" --repo \"$REPOSITORY\""))
        XCTAssertFalse(secretRegistration.contains("openssl req -x509"))

        XCTAssertTrue(workflow.contains("name: Notarized Release"))
        XCTAssertTrue(workflow.contains("workflow_dispatch:"))
        XCTAssertFalse(workflow.contains("push:"))
        XCTAssertFalse(workflow.contains("tags:"))
        XCTAssertTrue(workflow.contains("contents: write"))
        XCTAssertTrue(workflow.contains("actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"))
        XCTAssertTrue(workflow.contains("fetch-depth: 0"))
        XCTAssertTrue(workflow.contains("APP_VERSION=\"$(make -s print-app-version)\""))
        XCTAssertTrue(workflow.contains("BUILD_NUMBER=\"$(make -s print-build-number)\""))
        XCTAssertTrue(workflow.contains("BUILD_TAG=\"$(make -s print-build-tag)\""))
        XCTAssertTrue(workflow.contains("DMG_PATH=\"dist/Zap-${VERSION}.dmg\""))
        XCTAssertTrue(workflow.contains("if ! [[ \"$TAG\" =~ ^v[0-9]+\\.[0-9]+\\.[0-9]+$ ]]"))
        XCTAssertTrue(workflow.contains("git ls-remote --exit-code --tags origin \"refs/tags/$TAG\""))
        XCTAssertTrue(workflow.contains("swift test"))
        XCTAssertTrue(workflow.contains("CERTIFICATE_BASE64: ${{ secrets.DEVELOPER_ID_CERTIFICATE_BASE64 }}"))
        XCTAssertTrue(workflow.contains("CERTIFICATE_PASSWORD: ${{ secrets.DEVELOPER_ID_CERTIFICATE_PASSWORD }}"))
        XCTAssertTrue(workflow.contains("ASC_KEY_P8_BASE64: ${{ secrets.ASC_KEY_P8_BASE64 }}"))
        XCTAssertTrue(workflow.contains("SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}"))
        XCTAssertFalse(workflow.contains("ZAP_CERTIFICATE_BASE64"))
        XCTAssertTrue(workflow.contains("security create-keychain"))
        XCTAssertTrue(workflow.contains("security import \"$CERTIFICATE_PATH\""))
        XCTAssertTrue(workflow.contains("import_intermediate DeveloperIDG2CA"))
        XCTAssertTrue(workflow.contains("security set-key-partition-list -S apple-tool:,apple:,codesign:"))
        XCTAssertTrue(workflow.contains("awk '/\"Developer ID Application: / { print $2; exit }'"))
        XCTAssertFalse(workflow.contains("CODESIGN_IDENTITY=zap"))
        XCTAssertTrue(workflow.contains("xcrun notarytool store-credentials \"notarytool-profile\""))
        XCTAssertTrue(workflow.contains("make CODESIGN_IDENTITY=\"$CODESIGN_IDENTITY\" NOTARY_PROFILE=notarytool-profile NOTARY_KEYCHAIN=\"$KEYCHAIN_PATH\" VERSION=\"${{ steps.version.outputs.version }}\" BUILD_NUMBER=\"${{ steps.version.outputs.build_number }}\" BUILD_TAG=\"${{ steps.version.outputs.tag }}\" prepare-release-dmg"))
        XCTAssertTrue(workflow.contains("REPOSITORY: ${{ github.repository }}"))
        XCTAssertTrue(workflow.contains("scripts/generate-sparkle-appcast.sh"))
        XCTAssertTrue(workflow.contains("git tag \"${{ steps.version.outputs.tag }}\" \"$GITHUB_SHA\""))
        XCTAssertTrue(workflow.contains("git push origin \"refs/tags/${{ steps.version.outputs.tag }}\""))
        XCTAssertTrue(workflow.contains("softprops/action-gh-release@a06a81a03ee405af7f2048a818ed3f03bbf83c7b"))
        XCTAssertTrue(workflow.contains("make_latest: true"))
        XCTAssertTrue(workflow.contains("${{ steps.version.outputs.dmg_path }}"))
        XCTAssertTrue(workflow.contains("${{ steps.version.outputs.appcast_path }}"))
        XCTAssertTrue(workflow.contains("Developer ID signed and notarized DMG with Sparkle appcast."))
        XCTAssertTrue(workflow.contains("Roll back release tag on failure"))
        XCTAssertTrue(workflow.contains("git push origin \":refs/tags/$PUSHED_RELEASE_TAG\" || true"))
        XCTAssertTrue(workflow.contains("Cleanup signing artifacts"))
        XCTAssertTrue(workflow.contains("security delete-keychain \"$KPATH\""))

        assert("- name: Store notarization credentials", appearsBefore: "- name: Build, sign, notarize, and verify DMG", in: workflow)
        assert("- name: Build, sign, notarize, and verify DMG", appearsBefore: "- name: Generate Sparkle appcast", in: workflow)
        assert("- name: Generate Sparkle appcast", appearsBefore: "- name: Create tag", in: workflow)
        assert("- name: Create tag", appearsBefore: "- name: Create Release", in: workflow)
        assert("- name: Create Release", appearsBefore: "- name: Roll back release tag on failure", in: workflow)
    }

    func testVerifyDMGScriptReturnsFailureStatusAfterRetries() throws {
        let sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("VerifyZapDMGTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fakeBin = sandbox.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: sandbox) }
        let fakeHdiutil = fakeBin.appendingPathComponent("hdiutil")
        try "#!/usr/bin/env bash\nexit 42\n".write(to: fakeHdiutil, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeHdiutil.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", repositoryRoot().appendingPathComponent("scripts/verify-dmg.sh").path, "fake.dmg"]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = fakeBin.path + ":" + (environment["PATH"] ?? "")
        process.environment = environment
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 42)
    }

    private func assert(_ firstNeedle: String, appearsBefore secondNeedle: String, in haystack: String) {
        guard let firstRange = haystack.range(of: firstNeedle) else {
            XCTFail("Missing expected string: \(firstNeedle)")
            return
        }
        guard let secondRange = haystack.range(of: secondNeedle) else {
            XCTFail("Missing expected string: \(secondNeedle)")
            return
        }
        XCTAssertLessThan(firstRange.lowerBound, secondRange.lowerBound)
    }

    func testBundleEmbedsPermissionFlowResources() throws {
        let makefile = try String(contentsOf: repositoryRoot().appendingPathComponent("Makefile"), encoding: .utf8)

        XCTAssertTrue(makefile.contains("PERMISSION_FLOW_BUNDLE := PermissionFlow_PermissionFlow.bundle"))
        XCTAssertTrue(makefile.contains("ditto --norsrc --noextattr \"$$build_dir/$(PERMISSION_FLOW_BUNDLE)\" \"$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)\""))
        XCTAssertTrue(makefile.contains("test -d \"$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)\""))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
