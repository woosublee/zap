import XCTest

final class ReleaseWorkflowTests: XCTestCase {
    func testReleaseWorkflowBuildsAndUploadsSelfSignedDMG() throws {
        let root = repositoryRoot()
        let workflow = try String(contentsOf: root.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)
        let makefile = try String(contentsOf: root.appendingPathComponent("Makefile"), encoding: .utf8)
        let appcastScript = try String(contentsOf: root.appendingPathComponent("scripts/generate-sparkle-appcast.sh"), encoding: .utf8)
        let releaseLocal = try String(contentsOf: root.appendingPathComponent("scripts/release-local.sh"), encoding: .utf8)
        let secretRegistration = try String(contentsOf: root.appendingPathComponent("scripts/register-release-secrets.sh"), encoding: .utf8)

        XCTAssertTrue(makefile.contains("CODESIGN_IDENTITY ?= zap"))
        XCTAssertTrue(makefile.contains("RELEASE_CODESIGN_IDENTITY ?= $(CODESIGN_IDENTITY)"))
        XCTAssertTrue(makefile.contains("print-app-version:"))
        XCTAssertTrue(makefile.contains("print-build-number:"))
        XCTAssertTrue(makefile.contains("print-build-tag:"))
        XCTAssertTrue(makefile.contains("printf 'v%s\\n' \"$(VERSION)\""))
        XCTAssertTrue(makefile.contains("REPOSITORY ?= woosublee/zap"))
        XCTAssertTrue(makefile.contains("verify-dmg:"))
        XCTAssertTrue(makefile.contains("scripts/verify-dmg.sh \"$(RELEASE_DMG)\""))
        XCTAssertTrue(makefile.contains("sign-dmg:"))
        XCTAssertTrue(makefile.contains("codesign --force --sign \"$(CODESIGN_IDENTITY)\" \"$(RELEASE_DMG)\""))
        XCTAssertTrue(makefile.contains("scripts/generate-sparkle-appcast.sh"))
        XCTAssertFalse(makefile.contains("CODESIGN_IDENTITY=\"-\""))

        XCTAssertTrue(appcastScript.contains("REPOSITORY=\"${REPOSITORY:-woosublee/zap}\""))
        XCTAssertTrue(appcastScript.contains("APP_NAME=\"${APP_NAME:-Zap}\""))
        XCTAssertTrue(appcastScript.contains("SPARKLE_KEYCHAIN_ACCOUNT=\"${SPARKLE_KEYCHAIN_ACCOUNT:-com.woosublee.Zap.sparkle.ed25519}\""))
        XCTAssertTrue(appcastScript.contains("security find-generic-password"))
        XCTAssertTrue(appcastScript.contains("SPARKLE_PRIVATE_KEY"))
        XCTAssertTrue(appcastScript.contains("sign_update"))
        XCTAssertTrue(appcastScript.contains("--ed-key-file -"))
        XCTAssertTrue(appcastScript.contains("wc -c < \"$DMG_PATH\""))
        XCTAssertFalse(appcastScript.contains("-perm +111"))
        XCTAssertFalse(appcastScript.contains("stat -f%z"))

        XCTAssertTrue(releaseLocal.contains("CODESIGN_IDENTITY=\"zap\""))
        XCTAssertTrue(releaseLocal.contains("security find-identity -v -p codesigning"))
        XCTAssertTrue(releaseLocal.contains("gh repo view --json nameWithOwner --jq .nameWithOwner"))
        XCTAssertTrue(releaseLocal.contains("make VERSION=\"$VERSION\" BUILD_NUMBER=\"$BUILD_NUMBER\" BUILD_TAG=\"$RELEASE_TAG\" verify-dmg"))
        XCTAssertTrue(releaseLocal.contains("make VERSION=\"$VERSION\" BUILD_NUMBER=\"$BUILD_NUMBER\" BUILD_TAG=\"$RELEASE_TAG\" sign-dmg"))
        XCTAssertTrue(releaseLocal.contains("ALLOW_LOCAL_RELEASE_CLOBBER"))
        XCTAssertTrue(releaseLocal.contains("gh release upload \"$RELEASE_TAG\" \"$DMG_PATH\" \"$APPCAST_PATH\"\n"))
        XCTAssertTrue(releaseLocal.contains("gh release upload \"$RELEASE_TAG\" \"$DMG_PATH\" \"$APPCAST_PATH\" --clobber"))
        XCTAssertFalse(releaseLocal.contains("CODESIGN_IDENTITY=-"))

        XCTAssertTrue(secretRegistration.contains("ZAP_CERTIFICATE_BASE64"))
        XCTAssertTrue(secretRegistration.contains("ZAP_CERTIFICATE_PASSWORD"))
        XCTAssertTrue(secretRegistration.contains("SPARKLE_PRIVATE_KEY"))
        XCTAssertTrue(secretRegistration.contains("gh secret set"))
        XCTAssertTrue(secretRegistration.contains("openssl pkcs12 -legacy -export"))
        XCTAssertTrue(secretRegistration.contains("make -s check-eddsa-key"))

        XCTAssertTrue(workflow.contains("name: Self-signed Release"))
        XCTAssertTrue(workflow.contains("workflow_dispatch:"))
        XCTAssertFalse(workflow.contains("push:"))
        XCTAssertFalse(workflow.contains("tags:"))
        XCTAssertTrue(workflow.contains("contents: write"))
        XCTAssertTrue(workflow.contains("fetch-depth: 0"))
        XCTAssertTrue(workflow.contains("APP_VERSION=\"$(make -s print-app-version)\""))
        XCTAssertTrue(workflow.contains("BUILD_NUMBER=\"$(make -s print-build-number)\""))
        XCTAssertTrue(workflow.contains("BUILD_TAG=\"$(make -s print-build-tag)\""))
        XCTAssertTrue(workflow.contains("DMG_PATH=\"dist/Zap-${VERSION}.dmg\""))
        XCTAssertTrue(workflow.contains("if ! [[ \"$TAG\" =~ ^v[0-9]+\\.[0-9]+\\.[0-9]+$ ]]"))
        XCTAssertTrue(workflow.contains("git ls-remote --exit-code --tags origin \"refs/tags/$TAG\""))
        XCTAssertTrue(workflow.contains("swift test"))
        XCTAssertTrue(workflow.contains("ZAP_CERTIFICATE_BASE64"))
        XCTAssertTrue(workflow.contains("ZAP_CERTIFICATE_PASSWORD"))
        XCTAssertTrue(workflow.contains("SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}"))
        XCTAssertTrue(workflow.contains("security create-keychain"))
        XCTAssertTrue(workflow.contains("security import \"$CERTIFICATE_PATH\""))
        XCTAssertTrue(workflow.contains("security set-key-partition-list -S apple-tool:,apple:,codesign:"))
        XCTAssertTrue(workflow.contains("security find-identity -p codesigning \"$KEYCHAIN_PATH\" || true"))
        XCTAssertTrue(workflow.contains("CODESIGN_IDENTITY=zap"))
        XCTAssertFalse(workflow.contains("CODESIGN_IDENTITY=-"))
        XCTAssertTrue(workflow.contains("make CODESIGN_IDENTITY=\"$CODESIGN_IDENTITY\" VERSION=\"${{ steps.version.outputs.version }}\" BUILD_NUMBER=\"${{ steps.version.outputs.build_number }}\" BUILD_TAG=\"${{ steps.version.outputs.tag }}\" verify-dmg"))
        XCTAssertTrue(workflow.contains("make CODESIGN_IDENTITY=\"$CODESIGN_IDENTITY\" VERSION=\"${{ steps.version.outputs.version }}\" BUILD_NUMBER=\"${{ steps.version.outputs.build_number }}\" BUILD_TAG=\"${{ steps.version.outputs.tag }}\" sign-dmg"))
        XCTAssertFalse(workflow.contains("notarytool"))
        XCTAssertFalse(workflow.contains("stapler"))
        XCTAssertTrue(workflow.contains("REPOSITORY: ${{ github.repository }}"))
        XCTAssertTrue(workflow.contains("scripts/generate-sparkle-appcast.sh"))
        XCTAssertTrue(workflow.contains("git tag \"${{ steps.version.outputs.tag }}\" \"$GITHUB_SHA\""))
        XCTAssertTrue(workflow.contains("git push origin \"refs/tags/${{ steps.version.outputs.tag }}\""))
        XCTAssertTrue(workflow.contains("softprops/action-gh-release@a06a81a03ee405af7f2048a818ed3f03bbf83c7b"))
        XCTAssertTrue(workflow.contains("make_latest: true"))
        XCTAssertTrue(workflow.contains("${{ steps.version.outputs.dmg_path }}"))
        XCTAssertTrue(workflow.contains("${{ steps.version.outputs.appcast_path }}"))
        XCTAssertTrue(workflow.contains("Self-signed, non-notarized DMG with Sparkle appcast."))
        XCTAssertTrue(workflow.contains("Cleanup signing artifacts"))
        XCTAssertTrue(workflow.contains("security delete-keychain \"$KPATH\""))

        assert("- name: Build and verify self-signed DMG", appearsBefore: "- name: Sign DMG", in: workflow)
        assert("- name: Sign DMG", appearsBefore: "- name: Generate Sparkle appcast", in: workflow)
        assert("- name: Generate Sparkle appcast", appearsBefore: "- name: Create tag", in: workflow)
        assert("- name: Create tag", appearsBefore: "- name: Create Release", in: workflow)
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

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
